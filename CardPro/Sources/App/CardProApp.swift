import SwiftUI
import SwiftData

/// Observable object to manage incoming vCard files
@Observable
class IncomingCardManager {
    var pendingContact: ReceivedContact?
    var showImportSheet = false

    func handleIncomingURL(_ url: URL) {
        // Check if it's a vCard file
        guard url.pathExtension.lowercased() == "vcf" else { return }

        // Need to access the file (it might be in a secure location)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Parse the vCard
        if let contact = VCardParser.shared.parseFile(at: url) {
            pendingContact = contact
            showImportSheet = true
        }
    }
}

@main
struct CardProApp: App {
    @State private var incomingCardManager = IncomingCardManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BusinessCard.self,
            ReceivedContact.self,
        ])

        // Try to use CloudKit sync if available (requires paid Apple Developer account)
        // CloudKit container: iCloud.com.lman.cardpro
        let cloudKitContainerIdentifier = "iCloud.com.lman.cardpro"

        do {
            // First try with CloudKit enabled
            let cloudConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerIdentifier)
            )
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // Fall back to local-only storage if CloudKit fails
            // This happens when:
            // - User is not signed into iCloud
            // - App doesn't have CloudKit entitlements
            // - Other CloudKit errors
            print("CloudKit sync not available, using local storage: \(error.localizedDescription)")

            do {
                let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(incomingCardManager)
                .onOpenURL { url in
                    incomingCardManager.handleIncomingURL(url)
                }
                .sheet(isPresented: $incomingCardManager.showImportSheet) {
                    if let contact = incomingCardManager.pendingContact {
                        IncomingCardView(contact: contact) {
                            incomingCardManager.pendingContact = nil
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
