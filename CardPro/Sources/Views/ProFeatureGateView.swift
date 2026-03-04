import SwiftUI

struct ProFeatureGateView: View {
    @Environment(\.dismiss) private var dismiss
    let feature: ProFeature

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text(feature.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(feature.description)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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

                Spacer()

                // Subscribe button
                NavigationLink {
                    SubscriptionView()
                } label: {
                    Text(L10n.Subscription.upgradeToPro)
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        dismiss()
                    }
                }
            }
        }
    }
}

enum ProFeature {
    case csvExport
    case crm

    var icon: String {
        switch self {
        case .csvExport:
            return "tablecells.badge.ellipsis"
        case .crm:
            return "person.2.fill"
        }
    }

    var title: String {
        switch self {
        case .csvExport:
            return "CSV Export"
        case .crm:
            return "CRM"
        }
    }

    var description: String {
        switch self {
        case .csvExport:
            return "Export all your received contacts to a CSV file for use in other apps."
        case .crm:
            return "Track interactions, manage groups, and build stronger relationships with your contacts."
        }
    }
}
