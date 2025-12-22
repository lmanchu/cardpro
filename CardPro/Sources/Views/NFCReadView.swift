import SwiftUI

struct NFCReadView: View {
    let onScan: (ReceivedContact) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nfcService = NFCService.shared
    @State private var isScanning = false
    @State private var scanSuccess = false
    @State private var errorMessage: String?
    @State private var scannedContact: ReceivedContact?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // NFC animation
                ZStack {
                    // Pulse rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                            .scaleEffect(isScanning ? 1.2 : 1.0)
                            .opacity(isScanning ? 0 : 0.5)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.3),
                                value: isScanning
                            )
                    }

                    // NFC icon
                    if scanSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .padding(25)
                            .background(
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                            )
                    } else {
                        Image(systemName: "wave.3.left")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .padding(30)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                }

                // Status text
                VStack(spacing: 8) {
                    if scanSuccess, let contact = scannedContact {
                        Text("Card Received!")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text(contact.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)
                        if let company = contact.company {
                            Text(company)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let error = errorMessage {
                        Text("Scan Failed")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if isScanning {
                        Text("Hold near NFC tag...")
                            .font(.headline)
                        Text("Keep your iPhone close to the business card tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Ready to Scan")
                            .font(.headline)
                        Text("Tap the button below to scan an NFC business card")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if !nfcService.isNFCAvailable {
                        // NFC not available message
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("NFC is not available on this device")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if scanSuccess {
                        Button {
                            if let contact = scannedContact {
                                onScan(contact)
                            }
                            dismiss()
                        } label: {
                            Text("Save Contact")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            // Reset and scan again
                            scanSuccess = false
                            scannedContact = nil
                            errorMessage = nil
                        } label: {
                            Text("Scan Another")
                                .font(.subheadline)
                        }
                    } else {
                        Button {
                            scanNFC()
                        } label: {
                            Label(
                                isScanning ? "Scanning..." : "Scan NFC Tag",
                                systemImage: "wave.3.left"
                            )
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isScanning ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isScanning)
                    }
                }
                .padding(.horizontal)

                // Tips
                if !scanSuccess {
                    VStack(spacing: 4) {
                        Text("Hold your iPhone near an NFC business card tag")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Compatible with NDEF-formatted NFC tags")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Scan NFC Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func scanNFC() {
        isScanning = true
        errorMessage = nil

        nfcService.readVCard { result in
            DispatchQueue.main.async {
                isScanning = false
                switch result {
                case .success(let vcardString):
                    if let contact = parseVCard(vcardString) {
                        scannedContact = contact
                        scanSuccess = true
                    } else {
                        errorMessage = "Could not parse business card data"
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func parseVCard(_ string: String) -> ReceivedContact? {
        guard string.contains("BEGIN:VCARD") else { return nil }

        var firstName = ""
        var lastName = ""
        var localizedFirstName: String?
        var localizedLastName: String?
        var company: String?
        var title: String?
        var phone: String?
        var email: String?
        var website: String?

        let lines = string.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            if trimmedLine.hasPrefix("N:") {
                let parts = trimmedLine.dropFirst(2).components(separatedBy: ";")
                if parts.count >= 2 {
                    lastName = parts[0]
                    firstName = parts[1]
                }
            } else if trimmedLine.hasPrefix("FN:") {
                let fullName = String(trimmedLine.dropFirst(3))
                let parts = fullName.components(separatedBy: " ")
                if parts.count >= 2 {
                    firstName = parts[0]
                    lastName = parts.dropFirst().joined(separator: " ")
                } else if firstName.isEmpty {
                    firstName = fullName
                }
            } else if trimmedLine.hasPrefix("X-PHONETIC-FIRST-NAME:") {
                localizedFirstName = String(trimmedLine.dropFirst(22))
            } else if trimmedLine.hasPrefix("X-PHONETIC-LAST-NAME:") {
                localizedLastName = String(trimmedLine.dropFirst(21))
            } else if trimmedLine.hasPrefix("ORG:") {
                company = String(trimmedLine.dropFirst(4))
            } else if trimmedLine.hasPrefix("TITLE:") {
                title = String(trimmedLine.dropFirst(6))
            } else if trimmedLine.hasPrefix("TEL") {
                if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    phone = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                }
            } else if trimmedLine.hasPrefix("EMAIL") {
                if let colonIndex = trimmedLine.firstIndex(of: ":") {
                    email = String(trimmedLine[trimmedLine.index(after: colonIndex)...])
                }
            } else if trimmedLine.hasPrefix("URL:") {
                website = String(trimmedLine.dropFirst(4))
            }
        }

        guard !firstName.isEmpty || !lastName.isEmpty else { return nil }

        return ReceivedContact(
            firstName: firstName,
            lastName: lastName,
            localizedFirstName: localizedFirstName,
            localizedLastName: localizedLastName,
            company: company,
            title: title,
            phone: phone,
            email: email,
            website: website
        )
    }
}

#Preview {
    NFCReadView { contact in
        print("Received: \(contact.displayName)")
    }
}
