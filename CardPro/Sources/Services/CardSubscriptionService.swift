import Foundation
import FirebaseFirestore

// MARK: - Card Update

struct CardUpdate: Identifiable {
    let id: String
    let subscription: FirebaseSubscription
    let card: FirebaseCard
    let changes: [CardChange]
}

// MARK: - Card Subscription Service

@MainActor
class CardSubscriptionService: ObservableObject {
    static let shared = CardSubscriptionService()

    @Published private(set) var subscriptions: [FirebaseSubscription] = []
    @Published private(set) var pendingUpdates: [CardUpdate] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let firebaseService = FirebaseService.shared
    private let cardPublishService = CardPublishService.shared
    private var db: Firestore { firebaseService.firestore }

    private init() {}

    // MARK: - Subscribe to Card

    /// Subscribe to a published card
    func subscribe(toCardId cardId: String) async throws -> FirebaseSubscription {
        guard let userId = firebaseService.userId else {
            throw SubscriptionError.notAuthenticated
        }

        isLoading = true
        error = nil

        defer { isLoading = false }

        // Check if already subscribed
        let existingQuery = try await db.collection("subscriptions")
            .whereField("subscriberId", isEqualTo: userId)
            .whereField("cardId", isEqualTo: cardId)
            .getDocuments()

        if let existingDoc = existingQuery.documents.first {
            // Already subscribed - return existing subscription
            return parseSubscription(from: existingDoc.data(), id: existingDoc.documentID)
        }

        // Fetch the card to get owner info and current version
        guard let card = try await cardPublishService.fetchPublishedCard(id: cardId) else {
            throw SubscriptionError.cardNotFound
        }

        // Create subscription
        let subscriptionData: [String: Any] = [
            "subscriberId": userId,
            "cardId": cardId,
            "cardOwnerId": card.ownerId,
            "subscribedAt": FieldValue.serverTimestamp(),
            "lastNotifiedVersion": card.version,
            "lastSeenVersion": card.version,
            "notificationsEnabled": true
        ]

        let docRef = try await db.collection("subscriptions").addDocument(data: subscriptionData)

        let subscription = FirebaseSubscription(
            id: docRef.documentID,
            subscriberId: userId,
            cardId: cardId,
            cardOwnerId: card.ownerId,
            subscribedAt: Date(),
            lastNotifiedVersion: card.version,
            lastSeenVersion: card.version,
            notificationsEnabled: true
        )

        subscriptions.append(subscription)
        print("📩 Subscribed to card: \(cardId)")

        return subscription
    }

    // MARK: - Unsubscribe

    /// Unsubscribe from a card
    func unsubscribe(subscriptionId: String) async throws {
        try await db.collection("subscriptions").document(subscriptionId).delete()

        subscriptions.removeAll { $0.id == subscriptionId }
        pendingUpdates.removeAll { $0.subscription.id == subscriptionId }

        print("📩 Unsubscribed: \(subscriptionId)")
    }

    /// Unsubscribe by card ID
    func unsubscribe(fromCardId cardId: String) async throws {
        guard let userId = firebaseService.userId else {
            throw SubscriptionError.notAuthenticated
        }

        let query = try await db.collection("subscriptions")
            .whereField("subscriberId", isEqualTo: userId)
            .whereField("cardId", isEqualTo: cardId)
            .getDocuments()

        for doc in query.documents {
            try await doc.reference.delete()
        }

        subscriptions.removeAll { $0.cardId == cardId }
        pendingUpdates.removeAll { $0.subscription.cardId == cardId }
    }

    // MARK: - Fetch Subscriptions

    /// Fetch all subscriptions for current user
    func fetchSubscriptions() async throws {
        guard let userId = firebaseService.userId else {
            throw SubscriptionError.notAuthenticated
        }

        isLoading = true
        error = nil

        defer { isLoading = false }

        let query = try await db.collection("subscriptions")
            .whereField("subscriberId", isEqualTo: userId)
            .getDocuments()

        subscriptions = query.documents.map { doc in
            parseSubscription(from: doc.data(), id: doc.documentID)
        }

        print("📩 Fetched \(subscriptions.count) subscriptions")
    }

    // MARK: - Check for Updates

    /// Check for updates on all subscribed cards
    func checkForUpdates() async throws -> [CardUpdate] {
        guard !subscriptions.isEmpty else { return [] }

        isLoading = true
        error = nil

        defer { isLoading = false }

        var updates: [CardUpdate] = []

        for subscription in subscriptions {
            // Fetch the current card
            guard let card = try await cardPublishService.fetchPublishedCard(id: subscription.cardId) else {
                continue
            }

            // Check if card has been updated since last seen
            if card.version > subscription.lastSeenVersion {
                // Detect what changed
                let changes = detectChanges(fromVersion: subscription.lastSeenVersion, card: card)

                let update = CardUpdate(
                    id: subscription.id ?? UUID().uuidString,
                    subscription: subscription,
                    card: card,
                    changes: changes
                )
                updates.append(update)
            }
        }

        pendingUpdates = updates
        print("📩 Found \(updates.count) card updates")

        return updates
    }

    // MARK: - Apply Update

    /// Mark an update as seen
    func markUpdateAsSeen(_ update: CardUpdate) async throws {
        guard let subscriptionId = update.subscription.id else { return }

        try await db.collection("subscriptions").document(subscriptionId).updateData([
            "lastSeenVersion": update.card.version
        ])

        // Update local state
        if let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) {
            var updated = subscriptions[index]
            updated = FirebaseSubscription(
                id: updated.id,
                subscriberId: updated.subscriberId,
                cardId: updated.cardId,
                cardOwnerId: updated.cardOwnerId,
                subscribedAt: updated.subscribedAt,
                lastNotifiedVersion: updated.lastNotifiedVersion,
                lastSeenVersion: update.card.version,
                notificationsEnabled: updated.notificationsEnabled
            )
            subscriptions[index] = updated
        }

        pendingUpdates.removeAll { $0.id == update.id }
    }

    /// Apply update to a ReceivedContact
    func applyUpdate(_ update: CardUpdate, to contact: ReceivedContact) {
        let card = update.card

        contact.firstName = card.firstName
        contact.lastName = card.lastName
        contact.localizedFirstName = card.localizedFirstName
        contact.localizedLastName = card.localizedLastName
        contact.company = card.company
        contact.localizedCompany = card.localizedCompany
        contact.title = card.title
        contact.localizedTitle = card.localizedTitle
        contact.phone = card.phone
        contact.email = card.email
        contact.website = card.website

        // Convert Firebase custom fields back to local format
        contact.customFields = card.customFields.map { field in
            CustomField(
                id: UUID(uuidString: field.id) ?? UUID(),
                label: field.label,
                value: field.value,
                type: CustomField.FieldType(rawValue: field.type) ?? .text
            )
        }

        contact.senderCardVersion = card.version
        contact.lastUpdatedAt = Date()
        contact.hasUnreadUpdate = true

        print("📩 Applied update to contact: \(contact.displayName)")
    }

    // MARK: - Toggle Notifications

    /// Toggle notifications for a subscription
    func toggleNotifications(subscriptionId: String, enabled: Bool) async throws {
        try await db.collection("subscriptions").document(subscriptionId).updateData([
            "notificationsEnabled": enabled
        ])

        if let index = subscriptions.firstIndex(where: { $0.id == subscriptionId }) {
            var updated = subscriptions[index]
            updated = FirebaseSubscription(
                id: updated.id,
                subscriberId: updated.subscriberId,
                cardId: updated.cardId,
                cardOwnerId: updated.cardOwnerId,
                subscribedAt: updated.subscribedAt,
                lastNotifiedVersion: updated.lastNotifiedVersion,
                lastSeenVersion: updated.lastSeenVersion,
                notificationsEnabled: enabled
            )
            subscriptions[index] = updated
        }
    }

    // MARK: - Helpers

    private func parseSubscription(from data: [String: Any], id: String) -> FirebaseSubscription {
        let subscribedTimestamp = data["subscribedAt"] as? Timestamp

        return FirebaseSubscription(
            id: id,
            subscriberId: data["subscriberId"] as? String ?? "",
            cardId: data["cardId"] as? String ?? "",
            cardOwnerId: data["cardOwnerId"] as? String ?? "",
            subscribedAt: subscribedTimestamp?.dateValue() ?? Date(),
            lastNotifiedVersion: data["lastNotifiedVersion"] as? Int ?? 1,
            lastSeenVersion: data["lastSeenVersion"] as? Int ?? 1,
            notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true
        )
    }

    private func detectChanges(fromVersion: Int, card: FirebaseCard) -> [CardChange] {
        // In a real implementation, we'd store previous values
        // For now, just return a generic "card updated" change
        return [CardChange(field: "Card", oldValue: "v\(fromVersion)", newValue: "v\(card.version)")]
    }

    /// Check if subscribed to a card
    func isSubscribed(toCardId cardId: String) -> Bool {
        subscriptions.contains { $0.cardId == cardId }
    }

    /// Get subscription for a card
    func getSubscription(forCardId cardId: String) -> FirebaseSubscription? {
        subscriptions.first { $0.cardId == cardId }
    }
}

// MARK: - Errors

enum SubscriptionError: LocalizedError {
    case notAuthenticated
    case cardNotFound
    case alreadySubscribed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to subscribe to cards"
        case .cardNotFound:
            return "Card not found or no longer available"
        case .alreadySubscribed:
            return "You are already subscribed to this card"
        }
    }
}
