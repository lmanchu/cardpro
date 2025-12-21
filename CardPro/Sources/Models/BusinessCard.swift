import Foundation
import SwiftData

// MARK: - Custom Field

struct CustomField: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var value: String
    var type: FieldType

    enum FieldType: String, Codable, CaseIterable {
        case text = "Text"
        case phone = "Phone"
        case email = "Email"
        case url = "URL"
        case social = "Social"

        var icon: String {
            switch self {
            case .text: return "text.alignleft"
            case .phone: return "phone.fill"
            case .email: return "envelope.fill"
            case .url: return "link"
            case .social: return "person.2.fill"
            }
        }
    }

    // Common presets for quick add
    static let presets: [(label: String, type: FieldType)] = [
        ("LinkedIn", .social),
        ("Twitter/X", .social),
        ("Instagram", .social),
        ("Facebook", .social),
        ("WeChat", .social),
        ("LINE", .social),
        ("Telegram", .social),
        ("WhatsApp", .phone),
        ("Office Phone", .phone),
        ("Fax", .phone),
        ("Department", .text),
        ("Employee ID", .text),
    ]
}

// MARK: - Business Card

@Model
final class BusinessCard {
    var id: UUID
    var firstName: String              // Primary name (usually Western/English)
    var lastName: String
    var localizedFirstName: String?    // CJK name (中文/日文名)
    var localizedLastName: String?
    var company: String?
    var localizedCompany: String?      // 公司中文名
    var title: String?
    var localizedTitle: String?        // 職稱中文名
    var phone: String?
    var email: String?
    var website: String?
    var photoData: Data?               // 個人照片
    var cardImageData: Data?           // 名片設計圖（掃描/上傳/生成）
    var cardImageSource: String?       // "scan" | "upload" | "generated"
    var notes: String?
    var customFieldsData: Data?        // Encoded [CustomField]
    var cardVersion: Int               // Version for tracking updates
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date

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
        localizedFirstName: String? = nil,
        localizedLastName: String? = nil,
        company: String? = nil,
        localizedCompany: String? = nil,
        title: String? = nil,
        localizedTitle: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        photoData: Data? = nil,
        cardImageData: Data? = nil,
        cardImageSource: String? = nil,
        notes: String? = nil,
        customFields: [CustomField] = [],
        cardVersion: Int = 1,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.localizedFirstName = localizedFirstName
        self.localizedLastName = localizedLastName
        self.company = company
        self.localizedCompany = localizedCompany
        self.title = title
        self.localizedTitle = localizedTitle
        self.phone = phone
        self.email = email
        self.website = website
        self.photoData = photoData
        self.cardImageData = cardImageData
        self.cardImageSource = cardImageSource
        self.notes = notes
        self.customFieldsData = try? JSONEncoder().encode(customFields)
        self.cardVersion = cardVersion
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // MARK: - Computed Properties

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var localizedFullName: String? {
        guard let first = localizedLastName ?? localizedFirstName else { return nil }
        if let last = localizedFirstName, localizedLastName != nil {
            return "\(first)\(last)" // CJK names: 姓+名 no space
        }
        return first
    }

    var displayName: String {
        // Prefer Western name, fallback to localized
        if fullName.isEmpty {
            return localizedFullName ?? email ?? "Unnamed Card"
        }
        return fullName
    }

    /// Combined display showing both names if available (e.g., "Hagry Lin 林辰陽")
    var displayNameWithLocalized: String {
        let western = fullName
        let localized = localizedFullName

        if !western.isEmpty, let loc = localized, !loc.isEmpty {
            return "\(western) (\(loc))"
        } else if !western.isEmpty {
            return western
        } else if let loc = localized {
            return loc
        }
        return email ?? "Unnamed Card"
    }

    /// Generate vCard 3.0 format
    func toVCard() -> String {
        // Use localized name as primary if no Western name
        let primaryFirstName = firstName.isEmpty ? (localizedFirstName ?? "") : firstName
        let primaryLastName = lastName.isEmpty ? (localizedLastName ?? "") : lastName
        let primaryFullName = "\(primaryFirstName) \(primaryLastName)".trimmingCharacters(in: .whitespaces)

        var vcard = """
        BEGIN:VCARD
        VERSION:3.0
        N:\(primaryLastName);\(primaryFirstName);;;
        FN:\(primaryFullName)
        """

        // Add localized name as phonetic (for sorting/display in CJK systems)
        if let localizedLast = localizedLastName {
            vcard += "\nX-PHONETIC-LAST-NAME:\(localizedLast)"
        }
        if let localizedFirst = localizedFirstName {
            vcard += "\nX-PHONETIC-FIRST-NAME:\(localizedFirst)"
        }

        // Company - use both if available
        if let company = company, !company.isEmpty {
            vcard += "\nORG:\(company)"
        } else if let localizedCompany = localizedCompany, !localizedCompany.isEmpty {
            vcard += "\nORG:\(localizedCompany)"
        }

        // Title - use both if available
        if let title = title, !title.isEmpty {
            vcard += "\nTITLE:\(title)"
        } else if let localizedTitle = localizedTitle, !localizedTitle.isEmpty {
            vcard += "\nTITLE:\(localizedTitle)"
        }

        if let phone = phone, !phone.isEmpty {
            vcard += "\nTEL;TYPE=CELL:\(phone)"
        }

        if let email = email, !email.isEmpty {
            vcard += "\nEMAIL:\(email)"
        }

        if let website = website, !website.isEmpty {
            vcard += "\nURL:\(website)"
        }

        if let photoData = photoData {
            let base64Photo = photoData.base64EncodedString()
            vcard += "\nPHOTO;ENCODING=b;TYPE=JPEG:\(base64Photo)"
        }

        if let notes = notes, !notes.isEmpty {
            vcard += "\nNOTE:\(notes)"
        }

        // Custom fields
        for field in customFields {
            switch field.type {
            case .phone:
                vcard += "\nTEL;TYPE=\(field.label.uppercased()):\(field.value)"
            case .email:
                vcard += "\nEMAIL;TYPE=\(field.label.uppercased()):\(field.value)"
            case .url:
                vcard += "\nURL;TYPE=\(field.label.uppercased()):\(field.value)"
            case .social:
                // Use X-SOCIALPROFILE for social media
                let socialType = field.label.lowercased().replacingOccurrences(of: "/", with: "").replacingOccurrences(of: " ", with: "")
                vcard += "\nX-SOCIALPROFILE;TYPE=\(socialType):\(field.value)"
            case .text:
                // Use X- prefix for custom text fields
                let fieldName = field.label.uppercased().replacingOccurrences(of: " ", with: "-")
                vcard += "\nX-\(fieldName):\(field.value)"
            }
        }

        vcard += "\nEND:VCARD"

        return vcard
    }

    /// Increment version when card is updated
    func incrementVersion() {
        cardVersion += 1
        updatedAt = Date()
    }

    /// Generate vCard data for sharing
    func toVCardData() -> Data? {
        toVCard().data(using: .utf8)
    }
}
