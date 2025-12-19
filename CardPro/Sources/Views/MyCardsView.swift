import SwiftUI
import SwiftData

struct MyCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BusinessCard.createdAt, order: .reverse) private var cards: [BusinessCard]
    @State private var showingAddCard = false
    @State private var showingEditCard = false
    @State private var selectedCard: BusinessCard?
    @State private var showingShareSheet = false
    @State private var showingQRCode = false

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
                                    selectedCard = card
                                    showingEditCard = true
                                }
                        } else {
                            CardPreviewView(card: card)
                                .padding(.horizontal)
                                .onTapGesture {
                                    selectedCard = card
                                    showingEditCard = true
                                }
                        }

                        // Card info summary
                        VStack(spacing: 4) {
                            Text(card.displayName)
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
                        .padding(.top, 8)

                        // Share buttons
                        HStack(spacing: 16) {
                            ShareButton(title: "Share", icon: "square.and.arrow.up", color: .blue) {
                                selectedCard = card
                                showingShareSheet = true
                            }

                            ShareButton(title: "QR Code", icon: "qrcode", color: .purple) {
                                selectedCard = card
                                showingQRCode = true
                            }

                            ShareButton(title: "Edit", icon: "pencil", color: .orange) {
                                selectedCard = card
                                showingEditCard = true
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
            .sheet(isPresented: $showingEditCard) {
                if let card = selectedCard {
                    CardEditorView(card: card)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let card = selectedCard {
                    ShareSheet(card: card)
                }
            }
            .sheet(isPresented: $showingQRCode) {
                if let card = selectedCard {
                    QRCodeView(card: card)
                }
            }
        }
    }

    private func setDefaultCard(_ card: BusinessCard) {
        for c in cards {
            c.isDefault = (c.id == card.id)
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
