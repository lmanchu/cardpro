import SwiftUI

// MARK: - Subscribers List View

struct SubscribersListView: View {
    let card: BusinessCard
    @Environment(\.dismiss) private var dismiss
    @StateObject private var publishService = CardPublishService.shared
    @State private var subscribers: [Subscriber] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("載入中...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "載入失敗",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else if subscribers.isEmpty {
                    ContentUnavailableView(
                        "尚無訂閱者",
                        systemImage: "person.2.slash",
                        description: Text("當有人訂閱你的名片時，會顯示在這裡")
                    )
                } else {
                    List {
                        // Stats header
                        Section {
                            HStack(spacing: 24) {
                                StatItem(
                                    value: "\(subscribers.count)",
                                    label: "總訂閱數",
                                    icon: "person.2.fill",
                                    color: .blue
                                )

                                StatItem(
                                    value: "\(subscribers.filter { $0.notificationsEnabled }.count)",
                                    label: "開啟通知",
                                    icon: "bell.fill",
                                    color: .green
                                )
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }

                        // Subscribers list
                        Section("訂閱者") {
                            ForEach(subscribers) { subscriber in
                                SubscriberRow(subscriber: subscriber, currentVersion: card.cardVersion)
                            }
                        }
                    }
                }
            }
            .navigationTitle("訂閱者")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("關閉") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await loadSubscribers()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadSubscribers()
            }
        }
    }

    private func loadSubscribers() async {
        guard let cardId = card.firebaseCardId else {
            errorMessage = "名片尚未發布"
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            subscribers = try await publishService.getSubscribers(cardId: cardId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Subscriber Row

struct SubscriberRow: View {
    let subscriber: Subscriber
    let currentVersion: Int

    private var isUpToDate: Bool {
        subscriber.lastSeenVersion >= currentVersion
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundColor(.gray)
                }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("訂閱者")
                        .font(.headline)

                    if subscriber.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Text("訂閱於 \(subscriber.subscribedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Version status
            if isUpToDate {
                Label("已更新", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                Label("待更新", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SubscribersListView(card: BusinessCard(
        firstName: "Test",
        lastName: "User"
    ))
}
