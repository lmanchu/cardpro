import SwiftUI
import PassKit

struct WalletPassView: View {
    let card: BusinessCard
    @Environment(\.dismiss) private var dismiss
    @State private var showingSetupInfo = false

    private var isWalletAvailable: Bool {
        WalletPassService.shared.isWalletAvailable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Pass preview
                    VStack(spacing: 16) {
                        Text("Pass Preview")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        WalletPassPreview(card: card)
                            .padding(.horizontal)
                    }
                    .padding(.top)

                    // Status section
                    VStack(spacing: 16) {
                        // Wallet availability
                        HStack {
                            Image(systemName: isWalletAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isWalletAvailable ? .green : .red)
                            Text(isWalletAvailable ? "Wallet Available" : "Wallet Not Available")
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Developer account requirement
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Developer Account Required")
                                    .fontWeight(.semibold)
                                Spacer()
                            }

                            Text("Creating Apple Wallet passes requires an Apple Developer Program membership ($99/year) to sign the passes.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button {
                                showingSetupInfo = true
                            } label: {
                                Label("View Setup Instructions", systemImage: "info.circle")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Add to Wallet button (disabled without proper setup)
                    Button {
                        // Would add pass to wallet when properly configured
                    } label: {
                        HStack {
                            Image(systemName: "wallet.pass.fill")
                            Text("Add to Apple Wallet")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(true)
                    .opacity(0.5)
                    .padding(.horizontal)

                    // Alternative: Share vCard
                    VStack(spacing: 12) {
                        Text("Alternative Options")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("While Wallet passes require a developer account, you can still share your card using:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            AlternativeOption(icon: "qrcode", title: "QR Code")
                            AlternativeOption(icon: "airplayaudio", title: "AirDrop")
                            AlternativeOption(icon: "square.and.arrow.up", title: "Share")
                        }
                    }
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("Apple Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSetupInfo) {
                SetupInstructionsView()
            }
        }
    }
}

struct AlternativeOption: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 50, height: 50)
                .background(Color(.systemGray5))
                .clipShape(Circle())

            Text(title)
                .font(.caption)
        }
        .foregroundColor(.primary)
    }
}

struct SetupInstructionsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.black)

                        Text("Apple Wallet Setup")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Follow these steps to enable Apple Wallet passes for CardPro")
                            .foregroundColor(.secondary)
                    }
                    .padding()

                    // Steps
                    VStack(alignment: .leading, spacing: 20) {
                        SetupStep(
                            number: 1,
                            title: "Join Apple Developer Program",
                            description: "Enroll at developer.apple.com for $99/year. This is required to sign Wallet passes."
                        )

                        SetupStep(
                            number: 2,
                            title: "Register Pass Type ID",
                            description: "In the Developer Portal, go to Certificates, Identifiers & Profiles → Identifiers → Pass Type IDs. Create a new ID like \"pass.com.yourcompany.cardpro\"."
                        )

                        SetupStep(
                            number: 3,
                            title: "Create Certificate",
                            description: "Click on your Pass Type ID and create a new certificate. Follow the CSR process and download the certificate."
                        )

                        SetupStep(
                            number: 4,
                            title: "Update CardPro",
                            description: "Add your certificate to Keychain and update WalletPassService.swift with your Team ID and Pass Type Identifier."
                        )

                        SetupStep(
                            number: 5,
                            title: "Sign & Test",
                            description: "Build and test the app. Passes will now be signed with your certificate and can be added to Wallet."
                        )
                    }
                    .padding(.horizontal)

                    // Link to Apple Developer
                    Link(destination: URL(string: "https://developer.apple.com/programs/")!) {
                        HStack {
                            Image(systemName: "link")
                            Text("Apple Developer Program")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SetupStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WalletPassView(card: BusinessCard(
        firstName: "Leo",
        lastName: "Man",
        company: "IrisGo",
        title: "CEO",
        phone: "+886912345678",
        email: "leo@irisgo.co"
    ))
}
