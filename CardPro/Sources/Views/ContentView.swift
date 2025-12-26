import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab: Tab = .myCards

    enum Tab {
        case myCards
        case received
        case settings
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [BusinessCard.self, ReceivedContact.self], inMemory: true)
}
