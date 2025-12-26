import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Tab = .myCards
    @State private var showingQRCode = false
    @State private var showingShareSheet = false
    @State private var cardForShortcut: BusinessCard?
    @Query(filter: #Predicate<BusinessCard> { $0.isDefault }, sort: \BusinessCard.createdAt)
    private var defaultCards: [BusinessCard]
    @Query(sort: \BusinessCard.createdAt, order: .reverse)
    private var allCards: [BusinessCard]

    enum Tab {
        case myCards
        case received
        case settings
    }

    private var defaultCard: BusinessCard? {
        defaultCards.first ?? allCards.first
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MyCardsView()
                .tabItem {
                    Label(L10n.Tab.myCards, systemImage: "person.crop.rectangle.stack")
                }
                .tag(Tab.myCards)

            ReceivedCardsView()
                .tabItem {
                    Label(L10n.Tab.received, systemImage: "tray.and.arrow.down")
                }
                .tag(Tab.received)

            SettingsView()
                .tabItem {
                    Label(L10n.Tab.settings, systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .tint(.accentColor)
        .onReceive(NotificationCenter.default.publisher(for: .showQRCodeFromShortcut)) { _ in
            handleShowQRCode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shareCardFromShortcut)) { _ in
            handleShareCard()
        }
        .onAppear {
            checkShortcutFlags()
            updateDefaultCardInfo()
        }
        .onChange(of: defaultCard) { _, newCard in
            updateDefaultCardInfo()
        }
        .sheet(isPresented: $showingQRCode) {
            if let card = cardForShortcut {
                QRCodeView(card: card)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            if let card = cardForShortcut {
                ShareSheet(card: card)
            }
        }
    }

    private func handleShowQRCode() {
        guard let card = defaultCard else { return }
        cardForShortcut = card
        showingQRCode = true
        UserDefaults.standard.removeObject(forKey: "showQRCodeFromShortcut")
    }

    private func handleShareCard() {
        guard let card = defaultCard else { return }
        cardForShortcut = card
        showingShareSheet = true
        UserDefaults.standard.removeObject(forKey: "shareCardFromShortcut")
    }

    private func checkShortcutFlags() {
        // Check if app was launched from shortcut
        if UserDefaults.standard.bool(forKey: "showQRCodeFromShortcut") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                handleShowQRCode()
            }
        }
        if UserDefaults.standard.bool(forKey: "shareCardFromShortcut") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                handleShareCard()
            }
        }
    }

    private func updateDefaultCardInfo() {
        // Store default card info for Shortcuts that don't open the app
        guard let card = defaultCard else { return }
        let defaults = UserDefaults.standard
        defaults.set(card.displayName, forKey: "defaultCardName")
        defaults.set(card.title ?? "", forKey: "defaultCardTitle")
        defaults.set(card.company ?? "", forKey: "defaultCardCompany")
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [BusinessCard.self, ReceivedContact.self], inMemory: true)
}
