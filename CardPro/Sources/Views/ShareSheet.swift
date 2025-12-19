import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let card: BusinessCard

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create vCard file
        let vcardString = card.toVCard()
        let fileName = "\(card.displayName).vcf"

        // Create temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        do {
            try vcardString.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing vCard: \(error)")
        }

        // Create activity view controller
        let activityVC = UIActivityViewController(
            activityItems: [fileURL],
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
    @State private var qrImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 10)
                } else {
                    ProgressView()
                        .frame(width: 250, height: 250)
                }

                Text(card.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Scan to add contact")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                generateQRCode()
            }
        }
    }

    private func generateQRCode() {
        let vcardString = card.toVCard()

        guard let data = vcardString.data(using: .utf8) else { return }

        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return }

        // Scale up the QR code
        let scale = 10.0
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return }

        qrImage = UIImage(cgImage: cgImage)
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
