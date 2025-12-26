import SwiftUI
import SwiftData

struct MyCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessCard.sortOrder) private var cards: [BusinessCard]
    @State private var showingAddCard = false
    @State private var cardToEdit: BusinessCard?
    @State private var cardToShare: BusinessCard?
    @State private var cardForQR: BusinessCard?
    @State private var cardForAirDrop: BusinessCard?
    @State private var cardForNFC: BusinessCard?
    @State private var cardForWallet: BusinessCard?
    @State private var showingDeleteConfirm = false
    @State private var cardToDelete: BusinessCard?
    @State private var selectedCardIndex: Int = 0
    @State private var showingSubscription = false
    @StateObject private var subscriptionService = SubscriptionService.shared

    var defaultCard: BusinessCard? {
        cards.first(where: { $0.isDefault }) ?? cards.first
    }

    var currentCard: BusinessCard? {
        guard !cards.isEmpty, selectedCardIndex < cards.count else { return nil }
        return cards[selectedCardIndex]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !cards.isEmpty {
                        // Swipeable Card Carousel
                        cardCarouselSection

                        // Card info and actions for current card
                        if let card = currentCard {
                            cardInfoSummary(card: card)

                            // Set as Default button (if not already default)
                            if !card.isDefault {
                                Button {
                                    setDefaultCard(card)
                                } label: {
                                    Label(L10n.MyCards.setDefault, systemImage: "star")
                                        .font(.subheadline)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .clipShape(Capsule())
                                }
                            } else {
                                Label(L10n.MyCards.defaultCard, systemImage: "star.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }

                            shareButtonsSection(card: card)
                        }
                    } else {
                        emptyStateView
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(L10n.MyCards.title)
            .onAppear {
                updateWidgetIfNeeded()
                ensureDefaultCard()
                // Set initial index to default card
                if let defaultIndex = cards.firstIndex(where: { $0.isDefault }) {
                    selectedCardIndex = defaultIndex
                }
            }
            .onChange(of: cards) { _, _ in
                updateWidgetIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if subscriptionService.hasReachedFreeLimit(currentCardCount: cards.count) {
                            showingSubscription = true
                        } else {
                            showingAddCard = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                CardEditorView(card: nil)
            }
            .sheet(isPresented: $showingSubscription) {
                NavigationStack {
                    SubscriptionView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(L10n.Common.cancel) {
                                    showingSubscription = false
                                }
                            }
                        }
                }
            }
            .sheet(item: $cardToEdit) { card in
                CardEditorView(card: card)
            }
            .sheet(item: $cardToShare) { card in
                ShareSheet(card: card)
            }
            .sheet(item: $cardForQR) { card in
                QRCodeView(card: card)
            }
            .sheet(item: $cardForAirDrop) { card in
                AirDropShareView(card: card)
            }
            .sheet(item: $cardForNFC) { card in
                NFCWriteView(card: card)
            }
            .sheet(item: $cardForWallet) { card in
                WalletPassView(card: card)
            }
            .alert(L10n.CardEditor.deleteCard, isPresented: $showingDeleteConfirm) {
                Button(L10n.Common.cancel, role: .cancel) {
                    cardToDelete = nil
                }
                Button(L10n.Common.delete, role: .destructive) {
                    if let card = cardToDelete {
                        deleteCard(card)
                    }
                }
            } message: {
                if let card = cardToDelete {
                    Text(L10n.CardEditor.deleteConfirm(card.cardLabel))
                }
            }
        }
    }

    // MARK: - Card Carousel (Swipeable)

    @ViewBuilder
    private var cardCarouselSection: some View {
        VStack(spacing: 8) {
            TabView(selection: $selectedCardIndex) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    VStack(spacing: 0) {
                        // Card Label Badge
                        HStack {
                            Text(card.cardLabel)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(card.isDefault ? Color.orange : Color(.systemGray5))
                                .foregroundColor(card.isDefault ? .white : .primary)
                                .clipShape(Capsule())

                            if card.isDefault {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            Spacer()

                            // Edit button
                            Button {
                                cardToEdit = card
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)

                        // Card Image
                        if let cardImageData = card.cardImageData,
                           let uiImage = UIImage(data: cardImageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                                .padding(.horizontal)
                        } else {
                            CardPreviewView(card: card)
                                .padding(.horizontal)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 320)

            // Page indicator dots (card count)
            if cards.count > 1 {
                Text("\(selectedCardIndex + 1) / \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Main Card Display

    @ViewBuilder
    private func mainCardDisplay(card: BusinessCard) -> some View {
        if let cardImageData = card.cardImageData,
           let uiImage = UIImage(data: cardImageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                .padding(.horizontal)
                .onTapGesture {
                    cardToEdit = card
                }
        } else {
            CardPreviewView(card: card)
                .padding(.horizontal)
                .onTapGesture {
                    cardToEdit = card
                }
        }
    }

    // MARK: - Card Info Summary

    @ViewBuilder
    private func cardInfoSummary(card: BusinessCard) -> some View {
        VStack(spacing: 4) {
            Text(card.displayName)
                .font(.title2)
                .fontWeight(.bold)

            if let localizedName = card.localizedFullName,
               !card.fullName.isEmpty {
                Text(localizedName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let title = card.title, let company = card.company {
                if let localizedTitle = card.localizedTitle, let localizedCompany = card.localizedCompany {
                    Text("\(title) @ \(company)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(localizedTitle) @ \(localizedCompany)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    Text("\(title) @ \(company)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let company = card.company {
                Text(company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Share Buttons

    @ViewBuilder
    private func shareButtonsSection(card: BusinessCard) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ShareButton(title: L10n.Share.share, icon: "square.and.arrow.up", color: .blue) {
                    cardForAirDrop = card
                }

                ShareButton(title: L10n.Share.qrCode, icon: "qrcode", color: .purple) {
                    cardForQR = card
                }

                ShareButton(title: L10n.Share.edit, icon: "pencil", color: .gray) {
                    cardToEdit = card
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.rectangle.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text(L10n.MyCards.emptyTitle)
                .font(.title2)
                .fontWeight(.semibold)

            Text(L10n.MyCards.emptySubtitle)
                .foregroundStyle(.secondary)

            Button {
                showingAddCard = true
            } label: {
                Label(L10n.MyCards.emptyButton, systemImage: "plus")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
        }
        .padding(.top, 60)
    }

    // MARK: - All Cards List

    @ViewBuilder
    private var allCardsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Cards")
                    .font(.headline)
                Spacer()
                Text("\(cards.count) cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ForEach(cards) { card in
                CardListItem(
                    card: card,
                    isDefault: card.isDefault,
                    onTap: { setDefaultCard(card) },
                    onEdit: { cardToEdit = card },
                    onDelete: {
                        cardToDelete = card
                        showingDeleteConfirm = true
                    }
                )
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private func setDefaultCard(_ card: BusinessCard) {
        for c in cards {
            c.isDefault = (c.id == card.id)
        }
        // Update widget with new default card
        WidgetDataService.shared.updateWidget(with: card)
    }

    private func updateWidgetIfNeeded() {
        if let card = defaultCard {
            WidgetDataService.shared.updateWidget(with: card)
        } else {
            WidgetDataService.shared.clearWidget()
        }
    }

    private func ensureDefaultCard() {
        guard !cards.isEmpty else { return }

        // Find all cards marked as default
        let defaultCards = cards.filter { $0.isDefault }

        if defaultCards.isEmpty {
            // No default card - set the first one
            cards.first?.isDefault = true
        } else if defaultCards.count > 1 {
            // Multiple defaults found (legacy bug) - keep only the first one
            for (index, card) in defaultCards.enumerated() {
                if index > 0 {
                    card.isDefault = false
                }
            }
        }
    }

    private func deleteCard(_ card: BusinessCard) {
        let wasDefault = card.isDefault
        modelContext.delete(card)

        // If we deleted the default card, set a new default
        if wasDefault, let firstCard = cards.first(where: { $0.id != card.id }) {
            firstCard.isDefault = true
            WidgetDataService.shared.updateWidget(with: firstCard)
        }

        cardToDelete = nil
    }
}

// MARK: - Card Chip (for selector)

struct CardChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

struct ShareButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.15))
                    .foregroundColor(color)
                    .clipShape(Circle())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CardListItem: View {
    let card: BusinessCard
    let isDefault: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            // Card thumbnail
            if let cardImageData = card.cardImageData,
               let uiImage = UIImage(data: cardImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray4))
                    .frame(width: 60, height: 36)
                    .overlay {
                        Image(systemName: "person.crop.rectangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(card.cardLabel)
                        .font(.headline)
                    if isDefault {
                        Text("DEFAULT")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                Text(card.company ?? card.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(isDefault ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDefault ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    MyCardsView()
        .modelContainer(for: [BusinessCard.self], inMemory: true)
}
