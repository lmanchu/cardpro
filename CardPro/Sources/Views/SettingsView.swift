import SwiftUI
import CloudKit

struct SettingsView: View {
    @AppStorage("preferredShareMethod") private var preferredShareMethod = "airdrop"
    @AppStorage("autoImportToContacts") private var autoImportToContacts = false
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @State private var iCloudStatus: CKAccountStatus = .couldNotDetermine
    @State private var isCheckingStatus = true

    var body: some View {
        NavigationStack {
            Form {
                // Sharing preferences
                Section("Sharing") {
                    Picker("Preferred Method", selection: $preferredShareMethod) {
                        Label("AirDrop", systemImage: "airplayaudio").tag("airdrop")
                        Label("QR Code", systemImage: "qrcode").tag("qrcode")
                        Label("NFC", systemImage: "wave.3.right").tag("nfc")
                    }
                }

                // Receiving preferences
                Section("Receiving") {
                    Toggle(isOn: $autoImportToContacts) {
                        Label("Auto-import to Contacts", systemImage: "person.badge.plus")
                    }
                }

                // App preferences
                Section("App") {
                    Toggle(isOn: $hapticFeedback) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                }

                // iCloud Sync
                Section {
                    HStack {
                        Label("iCloud Sync", systemImage: "arrow.triangle.2.circlepath.icloud")
                        Spacer()
                        if isCheckingStatus {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(iCloudStatusColor)
                                    .frame(width: 8, height: 8)
                                Text(iCloudStatusText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if iCloudStatus != .available {
                        Text(iCloudStatusDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    if iCloudStatus == .available {
                        Text("Your cards sync automatically across all your devices signed into the same iCloud account.")
                    }
                }

                // Subscription
                Section("Subscription") {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Label("CardPro Pro", systemImage: "crown.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            Text("Free")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://irisgo.xyz/cardpro/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }

                    Link(destination: URL(string: "https://irisgo.xyz/cardpro/terms")!) {
                        Label("Terms of Service", systemImage: "doc.text.fill")
                    }

                    Link(destination: URL(string: "mailto:support@irisgo.xyz")!) {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                checkiCloudStatus()
            }
        }
    }

    private func checkiCloudStatus() {
        isCheckingStatus = true
        CKContainer.default().accountStatus { status, error in
            DispatchQueue.main.async {
                iCloudStatus = status
                isCheckingStatus = false
            }
        }
    }

    private var iCloudStatusColor: Color {
        switch iCloudStatus {
        case .available:
            return .green
        case .noAccount, .restricted, .temporarilyUnavailable:
            return .orange
        case .couldNotDetermine:
            return .gray
        @unknown default:
            return .gray
        }
    }

    private var iCloudStatusText: String {
        switch iCloudStatus {
        case .available:
            return "On"
        case .noAccount:
            return "Sign In Required"
        case .restricted:
            return "Restricted"
        case .temporarilyUnavailable:
            return "Unavailable"
        case .couldNotDetermine:
            return "Unknown"
        @unknown default:
            return "Unknown"
        }
    }

    private var iCloudStatusDescription: String {
        switch iCloudStatus {
        case .available:
            return ""
        case .noAccount:
            return "Sign in to iCloud in Settings to enable sync across your devices."
        case .restricted:
            return "iCloud access is restricted on this device."
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable. Please try again later."
        case .couldNotDetermine:
            return "Unable to determine iCloud status."
        @unknown default:
            return "Unable to determine iCloud status."
        }
    }
}

struct SubscriptionView: View {
    @State private var selectedPlan: String = "yearly"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("CardPro Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Unlock all features")
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "infinity", title: "Unlimited Cards", description: "Create as many cards as you need")
                    FeatureRow(icon: "arrow.triangle.2.circlepath", title: "iCloud Sync", description: "Access cards on all devices")
                    FeatureRow(icon: "paintbrush.fill", title: "Premium Templates", description: "Stand out with unique designs")
                    FeatureRow(icon: "chart.bar.fill", title: "Analytics", description: "Track card sharing stats")
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Plans
                VStack(spacing: 12) {
                    PlanButton(
                        title: "Yearly",
                        price: "$29.99/year",
                        savings: "Save 17%",
                        isSelected: selectedPlan == "yearly"
                    ) {
                        selectedPlan = "yearly"
                    }

                    PlanButton(
                        title: "Monthly",
                        price: "$2.99/month",
                        savings: nil,
                        isSelected: selectedPlan == "monthly"
                    ) {
                        selectedPlan = "monthly"
                    }
                }
                .padding(.horizontal)

                // Subscribe button
                Button {
                    // TODO: Implement StoreKit purchase
                } label: {
                    Text("Start Free Trial")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Text("7-day free trial, then \(selectedPlan == "yearly" ? "$29.99/year" : "$2.99/month")")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PlanButton: View {
    let title: String
    let price: String
    let savings: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        if let savings {
                            Text(savings)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                    Text(price)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .orange : .gray)
                    .font(.title2)
            }
            .padding()
            .background(isSelected ? Color.orange.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
}
