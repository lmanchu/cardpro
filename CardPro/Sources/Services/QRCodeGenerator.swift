import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Service for generating QR codes from business card data
class QRCodeGenerator {
    static let shared = QRCodeGenerator()

    private let context = CIContext()

    private init() {}

    /// Generate QR code image from a string (vCard data)
    func generateQRCode(from string: String, size: CGFloat = 300) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        // Create QR code filter
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

        guard let outputImage = filter.outputImage else { return nil }

        // Scale the image to desired size
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Convert to UIImage
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    /// Generate QR code from BusinessCard (uses vCard format)
    func generateQRCode(from card: BusinessCard, size: CGFloat = 300) -> UIImage? {
        // vCard without photo (photo makes QR code too dense)
        let vcard = generateCompactVCard(from: card)
        return generateQRCode(from: vcard, size: size)
    }

    /// Generate compact vCard without photo (for QR code and NFC)
    func generateCompactVCard(from card: BusinessCard) -> String {
        // Use localized name as primary if no Western name
        let primaryFirstName = card.firstName.isEmpty ? (card.localizedFirstName ?? "") : card.firstName
        let primaryLastName = card.lastName.isEmpty ? (card.localizedLastName ?? "") : card.lastName
        let primaryFullName = "\(primaryFirstName) \(primaryLastName)".trimmingCharacters(in: .whitespaces)

        var vcard = """
        BEGIN:VCARD
        VERSION:3.0
        N:\(primaryLastName);\(primaryFirstName);;;
        FN:\(primaryFullName)
        """

        // Add localized name as phonetic (for sorting/display in CJK systems)
        if let localizedLast = card.localizedLastName {
            vcard += "\nX-PHONETIC-LAST-NAME:\(localizedLast)"
        }
        if let localizedFirst = card.localizedFirstName {
            vcard += "\nX-PHONETIC-FIRST-NAME:\(localizedFirst)"
        }

        if let company = card.company, !company.isEmpty {
            vcard += "\nORG:\(company)"
        } else if let localizedCompany = card.localizedCompany, !localizedCompany.isEmpty {
            vcard += "\nORG:\(localizedCompany)"
        }

        if let title = card.title, !title.isEmpty {
            vcard += "\nTITLE:\(title)"
        } else if let localizedTitle = card.localizedTitle, !localizedTitle.isEmpty {
            vcard += "\nTITLE:\(localizedTitle)"
        }

        if let phone = card.phone, !phone.isEmpty {
            vcard += "\nTEL;TYPE=CELL:\(phone)"
        }

        if let email = card.email, !email.isEmpty {
            vcard += "\nEMAIL:\(email)"
        }

        if let website = card.website, !website.isEmpty {
            vcard += "\nURL:\(website)"
        }

        // Add custom fields (but skip photo to keep QR readable)
        for field in card.customFields {
            switch field.type {
            case .phone:
                vcard += "\nTEL;TYPE=\(field.label.uppercased()):\(field.value)"
            case .email:
                vcard += "\nEMAIL;TYPE=\(field.label.uppercased()):\(field.value)"
            case .url:
                vcard += "\nURL;TYPE=\(field.label.uppercased()):\(field.value)"
            case .social:
                let socialType = field.label.lowercased().replacingOccurrences(of: "/", with: "").replacingOccurrences(of: " ", with: "")
                vcard += "\nX-SOCIALPROFILE;TYPE=\(socialType):\(field.value)"
            case .text:
                let fieldName = field.label.uppercased().replacingOccurrences(of: " ", with: "-")
                vcard += "\nX-\(fieldName):\(field.value)"
            }
        }

        // Add CardPro subscription ID if published
        if let firebaseCardId = card.firebaseCardId, card.isPublished {
            // Add subscribable URL for web viewing
            vcard += "\nURL;TYPE=CARDPRO:https://cardpro-158e2.web.app/c/\(firebaseCardId)"
            // Add CardPro ID in NOTE for app to detect
            vcard += "\nNOTE:CardPro-ID:\(firebaseCardId)"
        }

        vcard += "\nEND:VCARD"

        return vcard
    }

    /// Generate QR code with custom colors
    func generateQRCode(from string: String, size: CGFloat = 300, foregroundColor: UIColor = .black, backgroundColor: UIColor = .white) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        // Create QR code filter
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Apply color filter
        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = outputImage
        colorFilter.color0 = CIColor(color: foregroundColor)
        colorFilter.color1 = CIColor(color: backgroundColor)

        guard let coloredImage = colorFilter.outputImage else { return nil }

        // Scale the image
        let scaleX = size / coloredImage.extent.size.width
        let scaleY = size / coloredImage.extent.size.height
        let scaledImage = coloredImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}
