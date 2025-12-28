import Foundation
import FirebaseFirestore
import FirebaseStorage

// MARK: - Card Publish Service

@MainActor
class CardPublishService: ObservableObject {
    static let shared = CardPublishService()

    @Published private(set) var isPublishing = false
    @Published private(set) var error: String?
    @Published var subscriberCounts: [String: Int] = [:]

    private let firebaseService = FirebaseService.shared
    private var db: Firestore { firebaseService.firestore }

    private init() {}

    // MARK: - Publish Card

    /// Publish a BusinessCard to Firebase for subscription
    /// Returns the Firebase card ID
    func publishCard(_ card: BusinessCard) async throws -> String {
        guard let userId = firebaseService.userId else {
            throw CardPublishError.notAuthenticated
        }

        isPublishing = true
        error = nil

        defer { isPublishing = false }

        // Upload photo if exists
        var photoUrl: String? = nil
        if let photoData = card.photoData {
            let path = "cards/\(userId)/\(card.id.uuidString)/photo.jpg"
            let url = try await firebaseService.uploadImage(photoData, path: path)
            photoUrl = url.absoluteString
        }

        // Prepare card data
        let cardData: [String: Any] = [
            "ownerId": userId,
            "version": card.cardVersion,
            "firstName": card.firstName,
            "lastName": card.lastName,
            "localizedFirstName": card.localizedFirstName as Any,
            "localizedLastName": card.localizedLastName as Any,
            "company": card.company as Any,
            "localizedCompany": card.localizedCompany as Any,
            "title": card.title as Any,
            "localizedTitle": card.localizedTitle as Any,
            "phone": card.phone as Any,
            "email": card.email as Any,
            "website": card.website as Any,
            "photoUrl": photoUrl as Any,
            "customFields": card.toFirebaseCustomFields().map { field in
                [
                    "id": field.id,
                    "label": field.label,
                    "value": field.value,
                    "type": field.type
                ]
            },
            "isPublic": true,
            "publishedAt": card.firebaseCardId == nil ? FieldValue.serverTimestamp() : card.createdAt,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        let cardId: String

        if let existingId = card.firebaseCardId {
            // Update existing published card
            try await db.collection("publishedCards").document(existingId).updateData(cardData)
            cardId = existingId
            print("📤 Updated published card: \(cardId)")
        } else {
            // Create new published card
            let docRef = try await db.collection("publishedCards").addDocument(data: cardData)
            cardId = docRef.documentID
            print("📤 Published new card: \(cardId)")
        }

        return cardId
    }

    // MARK: - Unpublish Card

    /// Unpublish a card from Firebase
    func unpublishCard(_ card: BusinessCard) async throws {
        guard let cardId = card.firebaseCardId else {
            return // Already not published
        }

        guard let userId = firebaseService.userId else {
            throw CardPublishError.notAuthenticated
        }

        // Delete the published card document
        try await db.collection("publishedCards").document(cardId).delete()

        // Delete photo from storage
        if card.photoData != nil {
            let path = "cards/\(userId)/\(card.id.uuidString)/photo.jpg"
            try? await firebaseService.deleteImage(path: path)
        }

        print("📤 Unpublished card: \(cardId)")
    }

    // MARK: - Fetch Published Card

    /// Fetch a published card by ID
    func fetchPublishedCard(id: String) async throws -> FirebaseCard? {
        let doc = try await db.collection("publishedCards").document(id).getDocument()

        guard doc.exists, let data = doc.data() else {
            return nil
        }

        return parseFirebaseCard(from: data, id: doc.documentID)
    }

    // MARK: - Get Subscriber Count

    /// Get the number of subscribers for a published card
    func getSubscriberCount(cardId: String) async throws -> Int {
        let snapshot = try await db.collection("subscriptions")
            .whereField("cardId", isEqualTo: cardId)
            .count
            .getAggregation(source: .server)

        return Int(truncating: snapshot.count)
    }

    // MARK: - Get Subscribers List

    /// Get list of subscribers for a published card
    func getSubscribers(cardId: String) async throws -> [Subscriber] {
        let snapshot = try await db.collection("subscriptions")
            .whereField("cardId", isEqualTo: cardId)
            .order(by: "subscribedAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> Subscriber? in
            let data = doc.data()
            guard let subscribedTimestamp = data["subscribedAt"] as? Timestamp else {
                return nil
            }

            return Subscriber(
                id: doc.documentID,
                subscribedAt: subscribedTimestamp.dateValue(),
                notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true,
                lastSeenVersion: data["lastSeenVersion"] as? Int ?? 0
            )
        }
    }

    // MARK: - Helpers

    private func parseFirebaseCard(from data: [String: Any], id: String) -> FirebaseCard {
        let customFieldsData = data["customFields"] as? [[String: Any]] ?? []
        let customFields = customFieldsData.map { fieldData in
            FirebaseCustomField(
                id: fieldData["id"] as? String ?? UUID().uuidString,
                label: fieldData["label"] as? String ?? "",
                value: fieldData["value"] as? String ?? "",
                type: fieldData["type"] as? String ?? "text"
            )
        }

        let publishedTimestamp = data["publishedAt"] as? Timestamp
        let updatedTimestamp = data["updatedAt"] as? Timestamp

        return FirebaseCard(
            id: id,
            ownerId: data["ownerId"] as? String ?? "",
            version: data["version"] as? Int ?? 1,
            firstName: data["firstName"] as? String ?? "",
            lastName: data["lastName"] as? String ?? "",
            localizedFirstName: data["localizedFirstName"] as? String,
            localizedLastName: data["localizedLastName"] as? String,
            company: data["company"] as? String,
            localizedCompany: data["localizedCompany"] as? String,
            title: data["title"] as? String,
            localizedTitle: data["localizedTitle"] as? String,
            phone: data["phone"] as? String,
            email: data["email"] as? String,
            website: data["website"] as? String,
            photoUrl: data["photoUrl"] as? String,
            customFields: customFields,
            isPublic: data["isPublic"] as? Bool ?? true,
            publishedAt: publishedTimestamp?.dateValue() ?? Date(),
            updatedAt: updatedTimestamp?.dateValue() ?? Date()
        )
    }
}

// MARK: - Errors

enum CardPublishError: LocalizedError {
    case notAuthenticated
    case cardNotFound
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to publish cards"
        case .cardNotFound:
            return "Card not found"
        case .uploadFailed:
            return "Failed to upload card data"
        }
    }
}

// MARK: - Subscriber Model

struct Subscriber: Identifiable {
    let id: String
    let subscribedAt: Date
    let notificationsEnabled: Bool
    let lastSeenVersion: Int
}
