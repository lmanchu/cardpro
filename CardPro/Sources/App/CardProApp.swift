import SwiftUI
import SwiftData

/// Observable object to manage incoming vCard and image files
@Observable
class IncomingCardManager {
    var pendingContact: ReceivedContact?
    var pendingImageData: Data?
    var showImportSheet = false

    // Buffer for handling multiple files from AirDrop
    private var pendingVCardURL: URL?
    private var pendingImageURL: URL?
    private var processingTimer: Timer?

    func handleIncomingURL(_ url: URL) {
        let ext = url.pathExtension.lowercased()

        // Need to access the file (it might be in a secure location)
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        switch ext {
        case "vcf":
            // Store vCard URL and wait briefly for potential image
            pendingVCardURL = url
            scheduleProcessing()

        case "jpg", "jpeg", "png":
            // Store image URL and wait briefly for potential vCard
            if let imageData = try? Data(contentsOf: url) {
                pendingImageURL = url
                pendingImageData = imageData
                scheduleProcessing()
            }

        default:
            break
        }
    }

    /// Schedule processing after a brief delay to allow both files to arrive
    private func scheduleProcessing() {
        processingTimer?.invalidate()
        processingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.processReceivedFiles()
        }
    }

    /// Process the received files (vCard and/or image)
    private func processReceivedFiles() {
        // If we have a vCard, parse it
        if let vcardURL = pendingVCardURL {
            let accessing = vcardURL.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    vcardURL.stopAccessingSecurityScopedResource()
                }
            }

            if let contact = VCardParser.shared.parseFile(at: vcardURL) {
                // Attach image if we received one
                if let imageData = pendingImageData {
                    contact.cardImageData = imageData
                }
                pendingContact = contact
                showImportSheet = true
            }
        } else if let imageData = pendingImageData {
            // Only received an image without vCard
            // Create a placeholder contact with just the image
            let contact = ReceivedContact()
            contact.cardImageData = imageData
            contact.notes = "Card image received - please add contact details"
            pendingContact = contact
            showImportSheet = true
        }

        // Reset state
        pendingVCardURL = nil
        pendingImageURL = nil
        pendingImageData = nil
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

        // Use local storage - CloudKit sync can be enabled later
        // CloudKit requires schema deployment which happens automatically on first run
        // but can cause crashes if not properly configured
        do {
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
