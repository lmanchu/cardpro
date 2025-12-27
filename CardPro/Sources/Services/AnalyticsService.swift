import Foundation
import SwiftUI

// MARK: - Share Event Types

enum ShareMethod: String, Codable, CaseIterable {
    case qrCode = "qr_code"
    case airdrop = "airdrop"
    case nfc = "nfc"
    case share = "share"  // Generic share sheet

    var displayName: String {
        switch self {
        case .qrCode: return "QR Code"
        case .airdrop: return "AirDrop"
        case .nfc: return "NFC"
        case .share: return "Share"
        }
    }

    var icon: String {
        switch self {
        case .qrCode: return "qrcode"
        case .airdrop: return "airplayaudio"
        case .nfc: return "wave.3.right"
        case .share: return "square.and.arrow.up"
        }
    }

    var color: Color {
        switch self {
        case .qrCode: return .purple
        case .airdrop: return .blue
        case .nfc: return .green
        case .share: return .orange
        }
    }
}

// MARK: - Share Event Model

struct ShareEvent: Codable, Identifiable {
    let id: UUID
    let cardID: UUID
    let method: ShareMethod
    let timestamp: Date

    init(cardID: UUID, method: ShareMethod) {
        self.id = UUID()
        self.cardID = cardID
        self.method = method
        self.timestamp = Date()
    }
}

// MARK: - Analytics Stats

struct CardAnalytics: Identifiable {
    let cardID: UUID
    let cardName: String
    var totalShares: Int
    var sharesByMethod: [ShareMethod: Int]
    var recentShares: [ShareEvent]
    var lastShareDate: Date?

    var id: UUID { cardID }

    init(cardID: UUID, cardName: String) {
        self.cardID = cardID
        self.cardName = cardName
        self.totalShares = 0
        self.sharesByMethod = [:]
        self.recentShares = []
        self.lastShareDate = nil
    }
}

struct OverallAnalytics {
    var totalShares: Int = 0
    var sharesByMethod: [ShareMethod: Int] = [:]
    var sharesThisWeek: Int = 0
    var sharesThisMonth: Int = 0
    var mostSharedCard: (name: String, count: Int)?
    var preferredMethod: ShareMethod?
}

// MARK: - Analytics Service

@MainActor
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    @Published private(set) var events: [ShareEvent] = []
    @Published private(set) var overallStats: OverallAnalytics = OverallAnalytics()

    private let userDefaults = UserDefaults.standard
    private let eventsKey = "shareEvents"

    private init() {
        loadEvents()
        calculateOverallStats()
    }

    // MARK: - Track Events

    /// Track a share event
    func trackShare(cardID: UUID, method: ShareMethod) {
        let event = ShareEvent(cardID: cardID, method: method)
        events.append(event)
        saveEvents()
        calculateOverallStats()

        print("📊 Tracked share: \(method.displayName) for card \(cardID)")
    }

    // MARK: - Get Analytics

    /// Get analytics for a specific card
    func getAnalytics(for cardID: UUID, cardName: String) -> CardAnalytics {
        var analytics = CardAnalytics(cardID: cardID, cardName: cardName)

        let cardEvents = events.filter { $0.cardID == cardID }
        analytics.totalShares = cardEvents.count

        // Count by method
        for method in ShareMethod.allCases {
            let count = cardEvents.filter { $0.method == method }.count
            if count > 0 {
                analytics.sharesByMethod[method] = count
            }
        }

        // Recent shares (last 10)
        analytics.recentShares = Array(cardEvents.suffix(10).reversed())

        // Last share date
        analytics.lastShareDate = cardEvents.last?.timestamp

        return analytics
    }

    /// Get shares count for a specific card
    func getShareCount(for cardID: UUID) -> Int {
        events.filter { $0.cardID == cardID }.count
    }

    /// Get shares this week for a card
    func getSharesThisWeek(for cardID: UUID) -> Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return events.filter { $0.cardID == cardID && $0.timestamp > oneWeekAgo }.count
    }

    // MARK: - Overall Stats

    private func calculateOverallStats() {
        var stats = OverallAnalytics()

        stats.totalShares = events.count

        // Count by method
        for method in ShareMethod.allCases {
            let count = events.filter { $0.method == method }.count
            if count > 0 {
                stats.sharesByMethod[method] = count
            }
        }

        // This week
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        stats.sharesThisWeek = events.filter { $0.timestamp > oneWeekAgo }.count

        // This month
        let oneMonthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        stats.sharesThisMonth = events.filter { $0.timestamp > oneMonthAgo }.count

        // Preferred method (most used)
        if let (method, _) = stats.sharesByMethod.max(by: { $0.value < $1.value }) {
            stats.preferredMethod = method
        }

        overallStats = stats
    }

    // MARK: - Persistence

    private func loadEvents() {
        if let data = userDefaults.data(forKey: eventsKey),
           let decoded = try? JSONDecoder().decode([ShareEvent].self, from: data) {
            events = decoded
        }
    }

    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(events) {
            userDefaults.set(encoded, forKey: eventsKey)
        }
    }

    // MARK: - Clear Data

    func clearAllData() {
        events = []
        overallStats = OverallAnalytics()
        userDefaults.removeObject(forKey: eventsKey)
    }
}

// MARK: - Analytics View

struct AnalyticsView: View {
    @StateObject private var analyticsService = AnalyticsService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !subscriptionService.subscriptionStatus.isPro {
                        // Pro feature banner
                        ProFeatureBanner()
                            .padding(.horizontal)
                    } else {
                        // Stats cards
                        StatsOverviewSection(stats: analyticsService.overallStats)
                            .padding(.horizontal)

                        // Share methods breakdown
                        if !analyticsService.overallStats.sharesByMethod.isEmpty {
                            ShareMethodsSection(sharesByMethod: analyticsService.overallStats.sharesByMethod)
                                .padding(.horizontal)
                        }

                        // Empty state
                        if analyticsService.events.isEmpty {
                            EmptyAnalyticsView()
                                .padding(.top, 40)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(L10n.Subscription.analytics)
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProFeatureBanner: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text(L10n.Subscription.analytics)
                .font(.title2)
                .fontWeight(.bold)

            Text(L10n.Subscription.analyticsDesc)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            NavigationLink {
                SubscriptionView()
            } label: {
                Text(L10n.Sync.proFeature)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct StatsOverviewSection: View {
    let stats: OverallAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)

            HStack(spacing: 16) {
                StatCard(
                    title: "Total Shares",
                    value: "\(stats.totalShares)",
                    icon: "square.and.arrow.up.fill",
                    color: .blue
                )

                StatCard(
                    title: "This Week",
                    value: "\(stats.sharesThisWeek)",
                    icon: "calendar",
                    color: .green
                )

                StatCard(
                    title: "This Month",
                    value: "\(stats.sharesThisMonth)",
                    icon: "calendar.badge.clock",
                    color: .purple
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ShareMethodsSection: View {
    let sharesByMethod: [ShareMethod: Int]

    private var sortedMethods: [(ShareMethod, Int)] {
        sharesByMethod.sorted { $0.value > $1.value }
    }

    private var maxCount: Int {
        sharesByMethod.values.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Share Methods")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(sortedMethods, id: \.0) { method, count in
                    HStack(spacing: 12) {
                        Image(systemName: method.icon)
                            .font(.title3)
                            .foregroundColor(method.color)
                            .frame(width: 30)

                        Text(method.displayName)
                            .font(.subheadline)

                        Spacer()

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(method.color)
                                    .frame(width: geo.size.width * CGFloat(count) / CGFloat(maxCount))
                            }
                        }
                        .frame(width: 100, height: 8)

                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

struct EmptyAnalyticsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Data Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Start sharing your cards to see analytics here")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    AnalyticsView()
}
