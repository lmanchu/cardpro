import Foundation
import SwiftData

// MARK: - Card Change

struct CardChange: Identifiable {
    let id = UUID()
    let field: String
    let oldValue: String
    let newValue: String
}

@Model
final class ReceivedContact {
    var id: UUID
    var firstName: String
    var lastName: String
    var company: String?
    var title: String?
    var phone: String?
    var email: String?
    var website: String?
    var photoData: Data?
    var cardImageData: Data?       // 收到的名片設計圖
    var customFieldsData: Data?    // Encoded [CustomField]
    var receivedAt: Date
    var receivedLocation: String?
    var receivedEvent: String?
    var notes: String?
    var isImportedToContacts: Bool
    var isFavorite: Bool
    var tags: [String]

    // Version tracking for update detection
    var senderCardId: UUID?        // Original card ID from sender
    var senderCardVersion: Int     // Version when received
    var isTracked: Bool            // Whether to track updates
    var lastUpdatedAt: Date?       // When card was last updated
    var hasUnreadUpdate: Bool      // Show badge for new updates

    // Computed property for custom fields
    var customFields: [CustomField] {
        get {
            guard let data = customFieldsData else { return [] }
            return (try? JSONDecoder().decode([CustomField].self, from: data)) ?? []
        }
        set {
            customFieldsData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        company: String? = nil,
        title: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        photoData: Data? = nil,
        cardImageData: Data? = nil,
        customFields: [CustomField] = [],
        receivedAt: Date = Date(),
        receivedLocation: String? = nil,
        receivedEvent: String? = nil,
        notes: String? = nil,
        isImportedToContacts: Bool = false,
        isFavorite: Bool = false,
        tags: [String] = [],
        senderCardId: UUID? = nil,
        senderCardVersion: Int = 1,
        isTracked: Bool = false
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.title = title
        self.phone = phone
        self.email = email
        self.website = website
        self.photoData = photoData
        self.cardImageData = cardImageData
        self.customFieldsData = try? JSONEncoder().encode(customFields)
        self.receivedAt = receivedAt
        self.receivedLocation = receivedLocation
        self.receivedEvent = receivedEvent
        self.notes = notes
        self.isImportedToContacts = isImportedToContacts
        self.isFavorite = isFavorite
        self.tags = tags
        self.senderCardId = senderCardId
        self.senderCardVersion = senderCardVersion
        self.isTracked = isTracked
        self.lastUpdatedAt = nil
        self.hasUnreadUpdate = false
    }

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var displayName: String {
        if fullName.isEmpty {
            return email ?? "Unknown"
        }
        return fullName
    }

    /// Create from vCard string
    static func fromVCard(_ vcardString: String) -> ReceivedContact? {
        let contact = ReceivedContact()

        let lines = vcardString.components(separatedBy: .newlines)

        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).uppercased()
            let value = String(parts[1])

            switch key {
            case "N":
                let nameParts = value.split(separator: ";")
                if nameParts.count >= 2 {
                    contact.lastName = String(nameParts[0])
                    contact.firstName = String(nameParts[1])
                }
            case "FN":
                if contact.firstName.isEmpty && contact.lastName.isEmpty {
                    let names = value.split(separator: " ", maxSplits: 1)
                    if names.count >= 2 {
                        contact.firstName = String(names[0])
                        contact.lastName = String(names[1])
                    } else {
                        contact.firstName = value
                    }
                }
            case "ORG":
                contact.company = value
            case "TITLE":
                contact.title = value
            case let k where k.starts(with: "TEL"):
                contact.phone = value
            case let k where k.starts(with: "EMAIL"):
                contact.email = value
            case "URL":
                contact.website = value
            case "NOTE":
                contact.notes = value
            default:
                break
            }
        }

        // Only return if we have some useful data
        guard !contact.firstName.isEmpty || !contact.lastName.isEmpty || contact.email != nil else {
            return nil
        }

        return contact
    }

    // MARK: - Update Detection

    /// Detect changes between this contact and a new version
    func detectChanges(from newContact: ReceivedContact) -> [CardChange] {
        var changes: [CardChange] = []

        // Compare basic fields
        if firstName != newContact.firstName {
            changes.append(CardChange(field: "First Name", oldValue: firstName, newValue: newContact.firstName))
        }
        if lastName != newContact.lastName {
            changes.append(CardChange(field: "Last Name", oldValue: lastName, newValue: newContact.lastName))
        }
        if company != newContact.company {
            changes.append(CardChange(field: "Company", oldValue: company ?? "", newValue: newContact.company ?? ""))
        }
        if title != newContact.title {
            changes.append(CardChange(field: "Title", oldValue: title ?? "", newValue: newContact.title ?? ""))
        }
        if phone != newContact.phone {
            changes.append(CardChange(field: "Phone", oldValue: phone ?? "", newValue: newContact.phone ?? ""))
        }
        if email != newContact.email {
            changes.append(CardChange(field: "Email", oldValue: email ?? "", newValue: newContact.email ?? ""))
        }
        if website != newContact.website {
            changes.append(CardChange(field: "Website", oldValue: website ?? "", newValue: newContact.website ?? ""))
        }

        // Compare custom fields
        let oldFields = customFields
        let newFields = newContact.customFields

        // Find removed fields
        for oldField in oldFields {
            if !newFields.contains(where: { $0.label == oldField.label }) {
                changes.append(CardChange(field: oldField.label, oldValue: oldField.value, newValue: "(removed)"))
            }
        }

        // Find added or changed fields
        for newField in newFields {
            if let oldField = oldFields.first(where: { $0.label == newField.label }) {
                if oldField.value != newField.value {
                    changes.append(CardChange(field: newField.label, oldValue: oldField.value, newValue: newField.value))
                }
            } else {
                changes.append(CardChange(field: newField.label, oldValue: "(new)", newValue: newField.value))
            }
        }

        return changes
    }

    /// Apply updates from a new version of the card
    func applyUpdates(from newContact: ReceivedContact) {
        firstName = newContact.firstName
        lastName = newContact.lastName
        company = newContact.company
        title = newContact.title
        phone = newContact.phone
        email = newContact.email
        website = newContact.website
        photoData = newContact.photoData
        cardImageData = newContact.cardImageData
        customFields = newContact.customFields
        senderCardVersion = newContact.senderCardVersion
        lastUpdatedAt = Date()
        hasUnreadUpdate = true
    }

    /// Mark update as read
    func markUpdateAsRead() {
        hasUnreadUpdate = false
    }
}
