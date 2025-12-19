import Foundation
import SwiftData

@Model
final class BusinessCard {
    var id: UUID
    var firstName: String
    var lastName: String
    var company: String?
    var title: String?
    var phone: String?
    var email: String?
    var website: String?
    var photoData: Data?           // 個人照片
    var cardImageData: Data?       // 名片設計圖（掃描/上傳/生成）
    var cardImageSource: String?   // "scan" | "upload" | "generated"
    var notes: String?
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date

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
        cardImageSource: String? = nil,
        notes: String? = nil,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
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
        self.cardImageSource = cardImageSource
        self.notes = notes
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }

    var displayName: String {
        if fullName.isEmpty {
            return email ?? "Unnamed Card"
        }
        return fullName
    }

    /// Generate vCard 3.0 format
    func toVCard() -> String {
        var vcard = """
        BEGIN:VCARD
        VERSION:3.0
        N:\(lastName);\(firstName);;;
        FN:\(fullName)
        """

        if let company = company, !company.isEmpty {
            vcard += "\nORG:\(company)"
        }

        if let title = title, !title.isEmpty {
            vcard += "\nTITLE:\(title)"
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

        vcard += "\nEND:VCARD"

        return vcard
    }

    /// Generate vCard data for sharing
    func toVCardData() -> Data? {
        toVCard().data(using: .utf8)
    }
}
