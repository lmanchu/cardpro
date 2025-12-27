import Foundation
import SwiftData
import SwiftUI

// MARK: - Interaction Type

enum InteractionType: String, Codable, CaseIterable, Identifiable {
    case call = "call"
    case meeting = "meeting"
    case email = "email"
    case note = "note"
    case linkedinMessage = "linkedin_message"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .call: return "Call"
        case .meeting: return "Meeting"
        case .email: return "Email"
        case .note: return "Note"
        case .linkedinMessage: return "LinkedIn"
        }
    }

    var icon: String {
        switch self {
        case .call: return "phone.fill"
        case .meeting: return "person.2.fill"
        case .email: return "envelope.fill"
        case .note: return "note.text"
        case .linkedinMessage: return "link"
        }
    }

    var color: Color {
        switch self {
        case .call: return .green
        case .meeting: return .blue
        case .email: return .orange
        case .note: return .purple
        case .linkedinMessage: return .cyan
        }
    }

    /// Weight for relationship score calculation
    var scoreWeight: Double {
        switch self {
        case .meeting: return 3.0
        case .call: return 2.0
        case .email: return 1.5
        case .linkedinMessage: return 1.2
        case .note: return 1.0
        }
    }
}

// MARK: - Interaction Model

@Model
final class Interaction {
    var id: UUID = UUID()
    var contactId: UUID              // Links to ReceivedContact.id
    var typeRaw: String = "note"     // Stored as string for CloudKit compatibility
    var title: String?
    var notes: String?
    var timestamp: Date = Date()
    var durationMinutes: Int?        // For calls/meetings
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Firebase sync
    var firebaseId: String?          // Firebase document ID
    var needsSync: Bool = true       // Whether needs to sync to Firebase

    // Computed property for type
    var type: InteractionType {
        get {
            InteractionType(rawValue: typeRaw) ?? .note
        }
        set {
            typeRaw = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        contactId: UUID,
        type: InteractionType,
        title: String? = nil,
        notes: String? = nil,
        timestamp: Date = Date(),
        durationMinutes: Int? = nil
    ) {
        self.id = id
        self.contactId = contactId
        self.typeRaw = type.rawValue
        self.title = title
        self.notes = notes
        self.timestamp = timestamp
        self.durationMinutes = durationMinutes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.firebaseId = nil
        self.needsSync = true
    }

    // MARK: - Display Helpers

    var displayTitle: String {
        if let title = title, !title.isEmpty {
            return title
        }
        return type.displayName
    }

    var formattedDuration: String? {
        guard let minutes = durationMinutes else { return nil }
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(remainingMinutes) min"
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// MARK: - Interaction for Firebase

struct FirebaseInteraction: Codable, Identifiable {
    var id: String?
    var userId: String
    var contactId: String
    var type: String
    var title: String?
    var notes: String?
    var timestamp: Date
    var durationMinutes: Int?
    var createdAt: Date
    var updatedAt: Date

    init(from interaction: Interaction, userId: String) {
        self.id = interaction.firebaseId
        self.userId = userId
        self.contactId = interaction.contactId.uuidString
        self.type = interaction.typeRaw
        self.title = interaction.title
        self.notes = interaction.notes
        self.timestamp = interaction.timestamp
        self.durationMinutes = interaction.durationMinutes
        self.createdAt = interaction.createdAt
        self.updatedAt = interaction.updatedAt
    }
}
