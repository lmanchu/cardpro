import Foundation
import SwiftData
import FirebaseFirestore

// MARK: - CRM Service

@MainActor
class CRMService: ObservableObject {
    static let shared = CRMService()

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let firebaseService = FirebaseService.shared
    private var db: Firestore { firebaseService.firestore }

    private init() {}

    // MARK: - Interactions

    /// Log a new interaction with a contact
    func logInteraction(
        for contact: ReceivedContact,
        type: InteractionType,
        title: String? = nil,
        notes: String? = nil,
        timestamp: Date = Date(),
        durationMinutes: Int? = nil,
        modelContext: ModelContext
    ) async throws -> Interaction {
        let interaction = Interaction(
            contactId: contact.id,
            type: type,
            title: title,
            notes: notes,
            timestamp: timestamp,
            durationMinutes: durationMinutes
        )

        // Save to local SwiftData
        modelContext.insert(interaction)

        // Update contact stats
        contact.interactionCount += 1
        contact.lastInteractionAt = timestamp

        // Recalculate relationship score
        let allInteractions = fetchInteractions(for: contact, modelContext: modelContext)
        contact.relationshipScore = calculateScore(for: contact, interactions: allInteractions)

        // Sync to Firebase if authenticated
        if let userId = firebaseService.userId {
            try await syncInteractionToFirebase(interaction, userId: userId)
        }

        print("📊 Logged \(type.displayName) interaction for \(contact.displayName)")

        return interaction
    }

    /// Fetch all interactions for a contact
    func fetchInteractions(for contact: ReceivedContact, modelContext: ModelContext) -> [Interaction] {
        let contactId = contact.id
        let predicate = #Predicate<Interaction> { interaction in
            interaction.contactId == contactId
        }

        let descriptor = FetchDescriptor<Interaction>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch recent interactions (last N)
    func fetchRecentInteractions(for contact: ReceivedContact, limit: Int = 5, modelContext: ModelContext) -> [Interaction] {
        let allInteractions = fetchInteractions(for: contact, modelContext: modelContext)
        return Array(allInteractions.prefix(limit))
    }

    /// Delete an interaction
    func deleteInteraction(_ interaction: Interaction, modelContext: ModelContext) async throws {
        // Delete from Firebase if synced
        if let firebaseId = interaction.firebaseId, let userId = firebaseService.userId {
            try await db.collection("interactions").document(firebaseId).delete()
        }

        // Delete locally
        modelContext.delete(interaction)

        print("📊 Deleted interaction")
    }

    // MARK: - Relationship Score

    /// Calculate relationship score for a contact based on interactions
    func calculateScore(for contact: ReceivedContact, interactions: [Interaction]) -> Double {
        guard !interactions.isEmpty else { return 0 }

        let now = Date()
        var totalScore: Double = 0
        let decayDays: Double = 30 // Score decays over 30 days

        for interaction in interactions {
            // Calculate time decay
            let daysSince = now.timeIntervalSince(interaction.timestamp) / (24 * 60 * 60)
            let decayFactor = max(0, 1 - (daysSince / decayDays))

            // Apply type weight
            let weight = interaction.type.scoreWeight

            // Duration bonus for calls/meetings
            var durationBonus: Double = 1.0
            if let duration = interaction.durationMinutes, duration > 0 {
                // Longer interactions get higher scores (cap at 2x)
                durationBonus = min(2.0, 1.0 + Double(duration) / 60.0)
            }

            // Add weighted score
            totalScore += weight * decayFactor * durationBonus
        }

        // Normalize to 0-100 scale
        // Base: 10 interactions with max weights over 30 days = ~30 points = 100 score
        let normalizedScore = min(100, (totalScore / 30) * 100)

        return normalizedScore.rounded()
    }

    /// Recalculate scores for all contacts
    func recalculateAllScores(modelContext: ModelContext) async {
        let descriptor = FetchDescriptor<ReceivedContact>()
        guard let contacts = try? modelContext.fetch(descriptor) else { return }

        for contact in contacts {
            let interactions = fetchInteractions(for: contact, modelContext: modelContext)
            contact.relationshipScore = calculateScore(for: contact, interactions: interactions)
            contact.interactionCount = interactions.count
            contact.lastInteractionAt = interactions.first?.timestamp
        }

        print("📊 Recalculated scores for \(contacts.count) contacts")
    }

    // MARK: - Contact Groups

    /// Create a new contact group
    func createGroup(
        name: String,
        colorHex: String = "#007AFF",
        iconName: String? = nil,
        modelContext: ModelContext
    ) async throws -> ContactGroup {
        let group = ContactGroup(
            name: name,
            colorHex: colorHex,
            iconName: iconName
        )

        modelContext.insert(group)

        // Sync to Firebase
        if let userId = firebaseService.userId {
            try await syncGroupToFirebase(group, userId: userId)
        }

        print("📁 Created group: \(name)")

        return group
    }

    /// Delete a contact group
    func deleteGroup(_ group: ContactGroup, modelContext: ModelContext) async throws {
        // Delete from Firebase if synced
        if let firebaseId = group.firebaseId, let userId = firebaseService.userId {
            try await db.collection("contactGroups").document(firebaseId).delete()
        }

        // Remove group from all contacts
        let descriptor = FetchDescriptor<ReceivedContact>()
        if let contacts = try? modelContext.fetch(descriptor) {
            for contact in contacts {
                var groups = contact.groupIds
                groups.removeAll { $0 == group.id }
                contact.groupIds = groups
            }
        }

        modelContext.delete(group)

        print("📁 Deleted group: \(group.name)")
    }

    /// Add contact to a group
    func addContact(_ contact: ReceivedContact, to group: ContactGroup) {
        var groups = contact.groupIds
        if !groups.contains(group.id) {
            groups.append(group.id)
            contact.groupIds = groups
        }
    }

    /// Remove contact from a group
    func removeContact(_ contact: ReceivedContact, from group: ContactGroup) {
        var groups = contact.groupIds
        groups.removeAll { $0 == group.id }
        contact.groupIds = groups
    }

    /// Fetch all groups
    func fetchGroups(modelContext: ModelContext) -> [ContactGroup] {
        let descriptor = FetchDescriptor<ContactGroup>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch contacts in a group
    func fetchContacts(in group: ContactGroup, modelContext: ModelContext) -> [ReceivedContact] {
        let groupId = group.id
        let descriptor = FetchDescriptor<ReceivedContact>()

        guard let contacts = try? modelContext.fetch(descriptor) else { return [] }

        return contacts.filter { $0.groupIds.contains(groupId) }
    }

    // MARK: - Firebase Sync

    private func syncInteractionToFirebase(_ interaction: Interaction, userId: String) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "contactId": interaction.contactId.uuidString,
            "type": interaction.typeRaw,
            "title": interaction.title as Any,
            "notes": interaction.notes as Any,
            "timestamp": Timestamp(date: interaction.timestamp),
            "durationMinutes": interaction.durationMinutes as Any,
            "createdAt": Timestamp(date: interaction.createdAt),
            "updatedAt": Timestamp(date: interaction.updatedAt)
        ]

        if let firebaseId = interaction.firebaseId {
            try await db.collection("interactions").document(firebaseId).updateData(data)
        } else {
            let docRef = try await db.collection("interactions").addDocument(data: data)
            interaction.firebaseId = docRef.documentID
            interaction.needsSync = false
        }
    }

    private func syncGroupToFirebase(_ group: ContactGroup, userId: String) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "name": group.name,
            "colorHex": group.colorHex,
            "iconName": group.iconName as Any,
            "createdAt": Timestamp(date: group.createdAt),
            "updatedAt": Timestamp(date: group.updatedAt)
        ]

        if let firebaseId = group.firebaseId {
            try await db.collection("contactGroups").document(firebaseId).updateData(data)
        } else {
            let docRef = try await db.collection("contactGroups").addDocument(data: data)
            group.firebaseId = docRef.documentID
            group.needsSync = false
        }
    }

    /// Sync all pending changes to Firebase
    func syncPendingChanges(modelContext: ModelContext) async {
        guard let userId = firebaseService.userId else { return }

        // Sync interactions
        let interactionDescriptor = FetchDescriptor<Interaction>(
            predicate: #Predicate<Interaction> { $0.needsSync == true }
        )

        if let interactions = try? modelContext.fetch(interactionDescriptor) {
            for interaction in interactions {
                try? await syncInteractionToFirebase(interaction, userId: userId)
            }
        }

        // Sync groups
        let groupDescriptor = FetchDescriptor<ContactGroup>(
            predicate: #Predicate<ContactGroup> { $0.needsSync == true }
        )

        if let groups = try? modelContext.fetch(groupDescriptor) {
            for group in groups {
                try? await syncGroupToFirebase(group, userId: userId)
            }
        }

        print("📊 Synced pending CRM changes to Firebase")
    }
}

// MARK: - Score Level

extension ReceivedContact {
    /// Relationship level based on score
    var relationshipLevel: RelationshipLevel {
        switch relationshipScore {
        case 0..<20: return .cold
        case 20..<40: return .warm
        case 40..<60: return .active
        case 60..<80: return .strong
        default: return .vip
        }
    }
}

enum RelationshipLevel: String, CaseIterable {
    case cold = "Cold"
    case warm = "Warm"
    case active = "Active"
    case strong = "Strong"
    case vip = "VIP"

    var color: String {
        switch self {
        case .cold: return "#8E8E93"
        case .warm: return "#FF9500"
        case .active: return "#34C759"
        case .strong: return "#007AFF"
        case .vip: return "#AF52DE"
        }
    }

    var icon: String {
        switch self {
        case .cold: return "snowflake"
        case .warm: return "flame"
        case .active: return "bolt.fill"
        case .strong: return "star.fill"
        case .vip: return "crown.fill"
        }
    }
}
