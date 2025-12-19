import Foundation
import SwiftData

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
    var receivedAt: Date
    var receivedLocation: String?
    var receivedEvent: String?
    var notes: String?
    var isImportedToContacts: Bool
    var isFavorite: Bool
    var tags: [String]

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
        receivedAt: Date = Date(),
        receivedLocation: String? = nil,
        receivedEvent: String? = nil,
        notes: String? = nil,
        isImportedToContacts: Bool = false,
        isFavorite: Bool = false,
        tags: [String] = []
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
        self.receivedAt = receivedAt
        self.receivedLocation = receivedLocation
        self.receivedEvent = receivedEvent
        self.notes = notes
        self.isImportedToContacts = isImportedToContacts
        self.isFavorite = isFavorite
        self.tags = tags
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
}
