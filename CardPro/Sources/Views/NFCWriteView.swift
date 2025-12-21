import SwiftUI

struct NFCWriteView: View {
    let card: BusinessCard
    @Environment(\.dismiss) private var dismiss
    @StateObject private var nfcService = NFCService.shared
    @State private var isWriting = false
    @State private var writeSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Card preview
                VStack(spacing: 16) {
                    if let photoData = card.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 100))
                            .foregroundColor(.orange)
                    }

                    VStack(spacing: 4) {
                        Text(card.displayNameWithLocalized)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let title = card.title, let company = card.company {
                            Text("\(title) @ \(company)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if let company = card.company {
                            Text(company)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // NFC animation
                ZStack {
                    // Pulse rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.orange.opacity(0.3), lineWidth: 2)
                            .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                            .scaleEffect(isWriting ? 1.2 : 1.0)
                            .opacity(isWriting ? 0 : 0.5)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.3),
                                value: isWriting
                            )
                    }

                    // NFC icon
                    if writeSuccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .padding(25)
                            .background(
                                Circle()
                                    .fill(Color.green.opacity(0.1))
                            )
                    } else {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                            .padding(30)
                            .background(
                                Circle()
                                    .fill(Color.orange.opacity(0.1))
                            )
                    }
                }

                // Status text
                VStack(spacing: 8) {
                    if writeSuccess {
                        Text("Card Written!")
                            .font(.headline)
                            .foregroundColor(.green)
                        Text("Your business card is now on the NFC tag")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let error = errorMessage {
                        Text("Write Failed")
                            .font(.headline)
                            .foregroundColor(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else if isWriting {
                        Text("Hold near NFC tag...")
                            .font(.headline)
                        Text("Keep your iPhone close until writing completes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Ready to Write")
                            .font(.headline)
                        Text("Tap the button below to start writing")
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
                    } else if writeSuccess {
                        Button {
                            dismiss()
                        } label: {
                            Text("Done")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button {
                            writeToNFC()
                        } label: {
                            Label(
                                isWriting ? "Writing..." : "Write to NFC Tag",
                                systemImage: "wave.3.right"
                            )
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isWriting ? Color.gray : Color.orange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isWriting)
                    }
                }
                .padding(.horizontal)

                // Tips
                if !writeSuccess {
                    VStack(spacing: 4) {
                        Text("Compatible with most NDEF NFC tags")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Recommended: NTAG215 or NTAG216")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Write to NFC")
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

    private func writeToNFC() {
        isWriting = true
        errorMessage = nil

        // Use compact vCard (without photo) for NFC
        let vcard = QRCodeGenerator.shared.generateCompactVCard(from: card)

        nfcService.writeVCard(vcard) { result in
            DispatchQueue.main.async {
                isWriting = false
                switch result {
                case .success:
                    writeSuccess = true
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NFCWriteView(card: BusinessCard(
        firstName: "Leo",
        lastName: "Man",
        company: "IrisGo",
        title: "CEO",
        email: "leo@irisgo.xyz"
    ))
}
