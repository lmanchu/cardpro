import SwiftUI

struct SettingsView: View {
    @AppStorage("preferredShareMethod") private var preferredShareMethod = "airdrop"
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var cloudSyncService = CloudSyncService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            Form {
                // iCloud Sync Section
                Section {
                    HStack {
                        Label(L10n.Sync.icloudSync, systemImage: cloudSyncService.syncStatus.icon)
                            .foregroundColor(cloudSyncService.syncStatus.color)
                        Spacer()
                        if subscriptionService.subscriptionStatus.isPro {
                            Text(cloudSyncService.syncStatus.displayText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L10n.Sync.proFeature)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }
                    }

                    if !subscriptionService.subscriptionStatus.isPro {
                        Text(L10n.Sync.proFeatureDesc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(L10n.Sync.title)
                } footer: {
                    if subscriptionService.subscriptionStatus.isPro && cloudSyncService.isCloudKitAvailable {
                        Text("Your cards sync automatically across all devices signed in with the same Apple ID.")
                    }
                }

                // Sharing preferences
                Section(L10n.Settings.sharing) {
                    Picker(L10n.Settings.preferredMethod, selection: $preferredShareMethod) {
                        Label(L10n.Settings.airdrop, systemImage: "airplayaudio").tag("airdrop")
                        Label(L10n.Settings.qrcode, systemImage: "qrcode").tag("qrcode")
                        Label(L10n.Settings.nfc, systemImage: "wave.3.right").tag("nfc")
                    }
                }

                // App preferences
                Section(L10n.Settings.app) {
                    Toggle(isOn: $hapticFeedback) {
                        Label(L10n.Settings.hapticFeedback, systemImage: "hand.tap")
                    }

                    NavigationLink {
                        LanguagePickerView(languageManager: languageManager, onLanguageChange: {
                            refreshID = UUID()
                        })
                    } label: {
                        HStack {
                            Label(L10n.Settings.language, systemImage: "globe")
                            Spacer()
                            Text(languageManager.displayName(for: languageManager.currentLanguage))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Subscription
                Section(L10n.Settings.subscription) {
                    NavigationLink {
                        SubscriptionView()
                    } label: {
                        HStack {
                            Label(L10n.Settings.cardproPro, systemImage: "crown.fill")
                                .foregroundColor(.orange)
                            Spacer()
                            if SubscriptionService.shared.subscriptionStatus.isPro {
                                Text("Pro")
                                    .foregroundColor(.orange)
                                    .fontWeight(.semibold)
                            } else {
                                Text(L10n.Settings.free)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // About
                Section(L10n.Settings.about) {
                    HStack {
                        Text(L10n.Settings.version)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://irisgo.xyz/cardpro/privacy")!) {
                        Label(L10n.Settings.privacyPolicy, systemImage: "hand.raised.fill")
                    }

                    Link(destination: URL(string: "https://irisgo.xyz/cardpro/terms")!) {
                        Label(L10n.Settings.termsOfService, systemImage: "doc.text.fill")
                    }

                    Link(destination: URL(string: "mailto:support@irisgo.xyz")!) {
                        Label(L10n.Settings.contactSupport, systemImage: "envelope.fill")
                    }
                }
            }
            .navigationTitle(L10n.Settings.title)
            .id(refreshID)
        }
    }
}

struct LanguagePickerView: View {
    @ObservedObject var languageManager: LanguageManager
    var onLanguageChange: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(LanguageManager.supportedLanguages, id: \.code) { language in
                Button {
                    languageManager.currentLanguage = language.code
                    onLanguageChange()
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.localName)
                                .foregroundColor(.primary)
                            if language.code != "system" {
                                Text(language.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if languageManager.currentLanguage == language.code {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.language)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SubscriptionView: View {
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var selectedProductID: String = SubscriptionProduct.yearly.rawValue
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text(L10n.Subscription.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    if subscriptionService.subscriptionStatus.isPro {
                        Label("Pro Active", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                    } else {
                        Text(L10n.Subscription.unlockAll)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 32)

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "infinity", title: L10n.Subscription.unlimitedCards, description: L10n.Subscription.unlimitedCardsDesc)
                    FeatureRow(icon: "arrow.triangle.2.circlepath", title: L10n.Subscription.icloudSync, description: L10n.Subscription.icloudSyncDesc)
                    FeatureRow(icon: "paintbrush.fill", title: L10n.Subscription.premiumTemplates, description: L10n.Subscription.premiumTemplatesDesc)
                    FeatureRow(icon: "chart.bar.fill", title: L10n.Subscription.analytics, description: L10n.Subscription.analyticsDesc)
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if !subscriptionService.subscriptionStatus.isPro {
                    // Plans from StoreKit
                    if subscriptionService.products.isEmpty {
                        ProgressView()
                            .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subscriptionService.products, id: \.id) { product in
                                let isYearly = product.id.contains("yearly")
                                PlanButton(
                                    title: product.displayName,
                                    price: product.displayPrice + (isYearly ? "/year" : "/month"),
                                    savings: isYearly ? L10n.Subscription.save17 : nil,
                                    isSelected: selectedProductID == product.id
                                ) {
                                    selectedProductID = product.id
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Subscribe button
                        Button {
                            purchase()
                        } label: {
                            HStack {
                                if subscriptionService.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(L10n.Subscription.startFreeTrial)
                                }
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(subscriptionService.isLoading)
                        .padding(.horizontal)

                        if let selectedProduct = subscriptionService.products.first(where: { $0.id == selectedProductID }) {
                            Text(L10n.Subscription.trialHint(selectedProduct.displayPrice))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Restore purchases
                        Button {
                            Task {
                                await subscriptionService.restorePurchases()
                            }
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.top, 8)
                    }
                }

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.Common.error, isPresented: $showingError) {
            Button(L10n.Common.ok) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func purchase() {
        guard let product = subscriptionService.products.first(where: { $0.id == selectedProductID }) else {
            return
        }

        Task {
            do {
                let success = try await subscriptionService.purchase(product)
                if success {
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
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
