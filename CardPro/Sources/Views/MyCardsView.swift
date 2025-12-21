import SwiftUI
import SwiftData

struct MyCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]
    @State private var showingAddCard = false
    @State private var cardToEdit: BusinessCard?
    @State private var cardToShare: BusinessCard?
    @State private var cardForQR: BusinessCard?
    @State private var cardForAirDrop: BusinessCard?
    @State private var cardForNFC: BusinessCard?
    @State private var cardForWallet: BusinessCard?

    var defaultCard: BusinessCard? {
        cards.first(where: { $0.isDefault }) ?? cards.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Main card display
                    if let card = defaultCard {
                        // Show card image if available, otherwise show preview
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

                        // Card info summary
                        VStack(spacing: 4) {
                            Text(card.displayName)
                                .font(.title2)
                                .fontWeight(.bold)

                            // Show localized name if available and different
                            if let localizedName = card.localizedFullName,
                               !card.fullName.isEmpty {
                                Text(localizedName)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }

                            // Title and Company
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

                        // Share buttons - Row 1
                        HStack(spacing: 12) {
                            ShareButton(title: "AirDrop", icon: "airplayaudio", color: .blue) {
                                cardForAirDrop = card
                            }

                            ShareButton(title: "QR Code", icon: "qrcode", color: .purple) {
                                cardForQR = card
                            }

                            ShareButton(title: "NFC", icon: "wave.3.right", color: .orange) {
                                cardForNFC = card
                            }
                        }

                        // Share buttons - Row 2
                        HStack(spacing: 12) {
                            ShareButton(title: "Share", icon: "square.and.arrow.up", color: .green) {
                                cardToShare = card
                            }

                            ShareButton(title: "Wallet", icon: "wallet.pass.fill", color: .black) {
                                cardForWallet = card
                            }

                            ShareButton(title: "Edit", icon: "pencil", color: .gray) {
                                cardToEdit = card
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    } else {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "person.crop.rectangle.badge.plus")
                                .font(.system(size: 64))
                                .foregroundStyle(.secondary)

                            Text("No Business Card Yet")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Create your first digital business card")
                                .foregroundStyle(.secondary)

                            Button {
                                showingAddCard = true
                            } label: {
                                Label("Create Card", systemImage: "plus")
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

                    // Card list (if more than one)
                    if cards.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Cards")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(cards) { card in
                                CardListItem(card: card, isDefault: card.isDefault)
                                    .onTapGesture {
                                        setDefaultCard(card)
                                    }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("My Cards")
            .onAppear {
                updateWidgetIfNeeded()
            }
            .onChange(of: cards) { _, _ in
                updateWidgetIfNeeded()
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddCard = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                CardEditorView(card: nil)
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
        }
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

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.displayName)
                    .font(.headline)
                if let company = card.company {
                    Text(company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isDefault {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MyCardsView()
        .modelContainer(for: [BusinessCard.self], inMemory: true)
}
