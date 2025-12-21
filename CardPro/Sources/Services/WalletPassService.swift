import Foundation
import PassKit

/// Service for generating Apple Wallet passes from business cards
class WalletPassService {
    static let shared = WalletPassService()

    private init() {}

    /// Check if Wallet is available on this device
    var isWalletAvailable: Bool {
        PKPassLibrary.isPassLibraryAvailable()
    }

    /// Generate a PKPass from a business card
    /// Note: This requires a pass type identifier and signing certificate from Apple Developer Program
    /// For now, returns nil as it requires paid developer account setup
    func generatePass(from card: BusinessCard) -> PKPass? {
        // Creating a valid PKPass requires:
        // 1. A Pass Type ID registered in Apple Developer Portal
        // 2. A Pass Type ID certificate for signing
        // 3. Apple WWDR certificate
        //
        // Steps to enable when you have a paid developer account:
        // 1. Register a Pass Type ID (e.g., "pass.com.lman.cardpro")
        // 2. Create a Pass Type ID certificate
        // 3. Export the certificate as .p12 file
        // 4. Use the certificate to sign the pass bundle

        // The pass structure would look like:
        // let passData = createPassBundle(from: card)
        // return try? PKPass(data: passData)

        return nil
    }

    /// Generate a VCard-based pass bundle (unsigned)
    /// This creates the JSON structure for a generic pass
    func createPassJSON(from card: BusinessCard) -> [String: Any] {
        var passDict: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": "pass.com.lman.cardpro", // Replace with your registered ID
            "serialNumber": card.id.uuidString,
            "teamIdentifier": "YOUR_TEAM_ID", // Replace with your Team ID
            "organizationName": card.company ?? "CardPro",
            "description": "Business Card - \(card.displayName)",
            "logoText": card.company ?? card.displayName,
        ]

        // Generic pass type for business card
        var genericDict: [String: Any] = [:]

        // Primary fields - Name
        var primaryFields: [[String: Any]] = []
        primaryFields.append([
            "key": "name",
            "label": "NAME",
            "value": card.displayName
        ])

        // Secondary fields - Title & Company
        var secondaryFields: [[String: Any]] = []
        if let title = card.title {
            secondaryFields.append([
                "key": "title",
                "label": "TITLE",
                "value": title
            ])
        }
        if let company = card.company {
            secondaryFields.append([
                "key": "company",
                "label": "COMPANY",
                "value": company
            ])
        }

        // Back fields - Contact details
        var backFields: [[String: Any]] = []
        if let phone = card.phone {
            backFields.append([
                "key": "phone",
                "label": "Phone",
                "value": phone
            ])
        }
        if let email = card.email {
            backFields.append([
                "key": "email",
                "label": "Email",
                "value": email
            ])
        }
        if let website = card.website {
            backFields.append([
                "key": "website",
                "label": "Website",
                "value": website
            ])
        }
        // Add localized name if available
        if let localizedName = card.localizedFullName {
            backFields.append([
                "key": "localizedName",
                "label": "Name (Local)",
                "value": localizedName
            ])
        }

        genericDict["primaryFields"] = primaryFields
        if !secondaryFields.isEmpty {
            genericDict["secondaryFields"] = secondaryFields
        }
        if !backFields.isEmpty {
            genericDict["backFields"] = backFields
        }

        passDict["generic"] = genericDict

        // Barcode with vCard data
        let vcardString = QRCodeGenerator.shared.generateCompactVCard(from: card)
        passDict["barcodes"] = [
            [
                "format": "PKBarcodeFormatQR",
                "message": vcardString,
                "messageEncoding": "iso-8859-1"
            ]
        ]

        // Colors
        passDict["backgroundColor"] = "rgb(255, 255, 255)"
        passDict["foregroundColor"] = "rgb(0, 0, 0)"
        passDict["labelColor"] = "rgb(100, 100, 100)"

        return passDict
    }

    /// Get instructions for setting up Apple Wallet passes
    var setupInstructions: String {
        """
        To enable Apple Wallet passes, you need:

        1. An Apple Developer Program membership ($99/year)

        2. Register a Pass Type ID:
           - Go to Apple Developer Portal
           - Certificates, Identifiers & Profiles
           - Identifiers → Pass Type IDs
           - Create new (e.g., "pass.com.lman.cardpro")

        3. Create a Pass Type ID Certificate:
           - In the same section, click on your Pass Type ID
           - Create Certificate
           - Follow the certificate signing request process

        4. Configure in Xcode:
           - Add the certificate to your keychain
           - Update WalletPassService with your Team ID
           - Update passTypeIdentifier with your registered ID

        5. Sign passes using the PassKit framework
        """
    }
}

// MARK: - Pass Preview (for showing what the pass would look like)

import SwiftUI

struct WalletPassPreview: View {
    let card: BusinessCard

    var body: some View {
        VStack(spacing: 0) {
            // Pass header
            HStack {
                VStack(alignment: .leading) {
                    Text(card.company ?? "CardPro")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "qrcode")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)

            Divider()

            // Pass content
            VStack(spacing: 16) {
                // Name
                VStack(spacing: 4) {
                    Text("NAME")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text(card.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let localizedName = card.localizedFullName {
                        Text(localizedName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }

                // Title & Company
                HStack(spacing: 24) {
                    if let title = card.title {
                        VStack(spacing: 4) {
                            Text("TITLE")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(title)
                                .font(.subheadline)
                        }
                    }

                    if let company = card.company {
                        VStack(spacing: 4) {
                            Text("COMPANY")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            Text(company)
                                .font(.subheadline)
                        }
                    }
                }

                // QR Code placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "qrcode")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    )
            }
            .padding()
            .background(Color.white)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
