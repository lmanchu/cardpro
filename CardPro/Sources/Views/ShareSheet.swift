import SwiftUI
import UIKit
import CoreImage.CIFilterBuiltins

struct ShareSheet: UIViewControllerRepresentable {
    let card: BusinessCard

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var activityItems: [Any] = []
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = card.displayName.replacingOccurrences(of: "/", with: "-")

        // 1. Add card image if available (for 儀式感！)
        if let cardImageData = card.cardImageData {
            let imageFileName = "\(safeName)-card.jpg"
            let imageURL = tempDir.appendingPathComponent(imageFileName)
            do {
                try cardImageData.write(to: imageURL)
                activityItems.append(imageURL)
            } catch {
                print("Error writing card image: \(error)")
            }
        }

        // 2. Add vCard file
        let vcardString = card.toVCard()
        let vcfFileName = "\(safeName).vcf"
        let vcfURL = tempDir.appendingPathComponent(vcfFileName)

        do {
            try vcardString.write(to: vcfURL, atomically: true, encoding: .utf8)
            activityItems.append(vcfURL)
        } catch {
            print("Error writing vCard: \(error)")
        }

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // Exclude some activity types
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .postToVimeo,
            .postToWeibo,
            .postToFlickr,
            .postToTwitter,
            .postToFacebook,
            .postToTencentWeibo
        ]

        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// QR Code View
struct QRCodeView: View {
    let card: BusinessCard
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage?
    @State private var savedBrightness: CGFloat = 0.5
    @State private var showingFullScreen = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Card info header
                VStack(spacing: 8) {
                    if let photoData = card.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                    }

                    Text(card.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let title = card.title {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let company = card.company {
                        Text(company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top)

                // QR Code
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        .onTapGesture {
                            showingFullScreen = true
                        }
                } else {
                    ProgressView()
                        .frame(width: 250, height: 250)
                }

                Text("Scan to add contact")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Tap QR code for full screen")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                // Share button
                Button {
                    shareQRCode()
                } label: {
                    Label("Share QR Code", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateQRCode()
                // Boost brightness for better scanning
                savedBrightness = UIScreen.main.brightness
                UIScreen.main.brightness = 1.0
            }
            .onDisappear {
                UIScreen.main.brightness = savedBrightness
            }
            .fullScreenCover(isPresented: $showingFullScreen) {
                FullScreenQRCodeView(card: card, qrImage: qrImage)
            }
        }
    }

    private func generateQRCode() {
        // Use QRCodeGenerator which excludes photo data for cleaner QR
        qrImage = QRCodeGenerator.shared.generateQRCode(from: card, size: 500)
    }

    private func shareQRCode() {
        guard let qrImage else { return }

        let activityVC = UIActivityViewController(
            activityItems: [qrImage],
            applicationActivities: nil
        )

        // Find the topmost presented view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              var topVC = window.rootViewController else {
            return
        }

        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}

// Full screen QR code for easier scanning
struct FullScreenQRCodeView: View {
    let card: BusinessCard
    let qrImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 32) {
                Text(card.displayName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                if let company = card.company {
                    Text(company)
                        .font(.headline)
                        .foregroundColor(.gray)
                }

                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(32)
                }

                Text("Scan to add contact")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .padding()

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - AirDrop Share View

struct AirDropShareView: View {
    let card: BusinessCard
    @Environment(\.dismiss) private var dismiss
    @State private var isSharing = false

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
                            .foregroundColor(.blue)
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

                // AirDrop animation
                VStack(spacing: 16) {
                    ZStack {
                        // Pulse animation
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                                .frame(width: 120 + CGFloat(i * 40), height: 120 + CGFloat(i * 40))
                                .scaleEffect(isSharing ? 1.2 : 1.0)
                                .opacity(isSharing ? 0 : 0.5)
                                .animation(
                                    .easeInOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.3),
                                    value: isSharing
                                )
                        }

                        // AirDrop icon
                        Image(systemName: "airplayaudio")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                            .padding(30)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }

                    Text("Ready to AirDrop")
                        .font(.headline)

                    Text("Share your card with nearby devices")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Share button
                Button {
                    shareViaAirDrop()
                } label: {
                    Label("Share via AirDrop", systemImage: "airplayaudio")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                // Tips
                Text("Make sure AirDrop is enabled on both devices")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 24)
            }
            .navigationTitle("AirDrop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isSharing = true
            }
        }
    }

    private func shareViaAirDrop() {
        let tempDir = FileManager.default.temporaryDirectory
        let safeName = card.displayName.replacingOccurrences(of: "/", with: "-")

        var activityItems: [Any] = []

        // Add card image if available
        if let cardImageData = card.cardImageData {
            let imageFileName = "\(safeName)-card.jpg"
            let imageURL = tempDir.appendingPathComponent(imageFileName)
            do {
                try cardImageData.write(to: imageURL)
                activityItems.append(imageURL)
            } catch {
                print("Error writing card image: \(error)")
            }
        }

        // Add vCard file
        let vcardString = card.toVCard()
        let vcfFileName = "\(safeName).vcf"
        let vcfURL = tempDir.appendingPathComponent(vcfFileName)

        do {
            try vcardString.write(to: vcfURL, atomically: true, encoding: .utf8)
            activityItems.append(vcfURL)
        } catch {
            print("Error writing vCard: \(error)")
            return
        }

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // Exclude non-AirDrop types to prioritize AirDrop
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks,
            .postToVimeo,
            .postToWeibo,
            .postToFlickr,
            .postToTwitter,
            .postToFacebook,
            .postToTencentWeibo,
            .print,
            .saveToCameraRoll,
            .copyToPasteboard
        ]

        // Find the topmost presented view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              var topVC = window.rootViewController else {
            return
        }

        // Traverse to the topmost presented controller
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        topVC.present(activityVC, animated: true)
    }
}

#Preview("Share Sheet") {
    ShareSheet(card: BusinessCard(
        firstName: "Leo",
        lastName: "Man",
        company: "IrisGo",
        email: "leo@irisgo.xyz"
    ))
}

#Preview("QR Code") {
    QRCodeView(card: BusinessCard(
        firstName: "Leo",
        lastName: "Man",
        company: "IrisGo",
        email: "leo@irisgo.xyz"
    ))
}

#Preview("AirDrop") {
    AirDropShareView(card: BusinessCard(
        firstName: "Leo",
        lastName: "Man",
        company: "IrisGo",
        title: "CEO",
        email: "leo@irisgo.xyz"
    ))
}
