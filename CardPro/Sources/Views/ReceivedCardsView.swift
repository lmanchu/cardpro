import SwiftUI
import SwiftData

struct ReceivedCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReceivedContact.receivedAt, order: .reverse) private var contacts: [ReceivedContact]
    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var selectedContact: ReceivedContact?
    @State private var showingAddOptions = false
    @State private var showingDocumentScanner = false
    @State private var showingQRScanner = false
    @State private var showingManualEntry = false
    @State private var scannedCardData: ScannedCardData?
    @State private var pendingUpdate: PendingCardUpdate?

    var allTags: [String] {
        TagService.shared.getAllTags(from: contacts)
    }

    var filteredContacts: [ReceivedContact] {
        var result = contacts

        // Filter by tag first
        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        // Then filter by search text
        if !searchText.isEmpty {
            result = result.filter { contact in
                contact.searchableText.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)

                        Text("No Cards Received")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Cards you receive will appear here")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 0) {
                        // Tag filter chips
                        if !allTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    // All button
                                    TagChip(
                                        label: "All",
                                        color: .accentColor,
                                        isSelected: selectedTag == nil
                                    ) {
                                        selectedTag = nil
                                    }

                                    // Tag chips
                                    ForEach(allTags, id: \.self) { tag in
                                        TagChip(
                                            label: tag,
                                            color: TagService.shared.color(for: tag),
                                            isSelected: selectedTag == tag
                                        ) {
                                            if selectedTag == tag {
                                                selectedTag = nil
                                            } else {
                                                selectedTag = tag
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            .background(Color(.systemGroupedBackground))
                        }

                        List {
                            ForEach(filteredContacts) { contact in
                                ReceivedContactRow(contact: contact)
                                    .onTapGesture {
                                        selectedContact = contact
                                    }
                            }
                            .onDelete(perform: deleteContacts)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search contacts")
                }
            }
            .navigationTitle("Received")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddOptions = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Add Contact", isPresented: $showingAddOptions) {
                Button {
                    showingDocumentScanner = true
                } label: {
                    Label("Scan Physical Card", systemImage: "doc.viewfinder")
                }

                Button {
                    showingQRScanner = true
                } label: {
                    Label("Scan QR Code", systemImage: "qrcode.viewfinder")
                }

                Button {
                    showingManualEntry = true
                } label: {
                    Label("Manual Entry", systemImage: "square.and.pencil")
                }

                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $selectedContact) { contact in
                ReceivedContactDetailView(contact: contact)
            }
            .sheet(isPresented: $showingDocumentScanner) {
                DocumentScannerForReceived { imageData, ocrInfo in
                    scannedCardData = ScannedCardData(
                        cardImageData: imageData,
                        ocrInfo: ocrInfo
                    )
                }
            }
            .sheet(isPresented: $showingQRScanner) {
                QRCodeScannerView { contact in
                    handleReceivedContact(contact)
                }
            }
            .sheet(item: $pendingUpdate) { update in
                CardUpdateConfirmationView(
                    existingContact: update.existingContact,
                    newContact: update.newContact,
                    changes: update.changes,
                    onApply: {
                        update.existingContact.applyUpdates(from: update.newContact)
                        pendingUpdate = nil
                    },
                    onSkip: {
                        // Add as new contact instead
                        modelContext.insert(update.newContact)
                        pendingUpdate = nil
                    },
                    onCancel: {
                        pendingUpdate = nil
                    }
                )
            }
            .sheet(isPresented: $showingManualEntry) {
                ReceivedContactEditorView(
                    existingContact: nil,
                    cardImageData: nil,
                    ocrInfo: nil
                )
            }
            .sheet(item: $scannedCardData) { data in
                ReceivedContactEditorView(
                    existingContact: nil,
                    cardImageData: data.cardImageData,
                    ocrInfo: data.ocrInfo
                )
            }
        }
    }

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredContacts[index])
        }
    }

    private func handleReceivedContact(_ newContact: ReceivedContact) {
        // Check if this matches an existing tracked contact
        if let existingContact = CardUpdateService.shared.findExistingContact(
            for: newContact,
            in: contacts
        ) {
            // Found a match - show update confirmation
            let changes = existingContact.detectChanges(from: newContact)
            if !changes.isEmpty {
                pendingUpdate = PendingCardUpdate(
                    existingContact: existingContact,
                    newContact: newContact,
                    changes: changes
                )
            } else {
                // No changes, just update the version
                existingContact.senderCardVersion = newContact.senderCardVersion
            }
        } else {
            // New contact
            modelContext.insert(newContact)
        }
    }
}

// MARK: - Pending Card Update

struct PendingCardUpdate: Identifiable {
    let id = UUID()
    let existingContact: ReceivedContact
    let newContact: ReceivedContact
    let changes: [CardChange]
}

// MARK: - Card Update Confirmation View

struct CardUpdateConfirmationView: View {
    let existingContact: ReceivedContact
    let newContact: ReceivedContact
    let changes: [CardChange]
    let onApply: () -> Void
    let onSkip: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("Card Update Detected")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("\(existingContact.displayName) has updated their card")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                // Changes list
                List {
                    Section("Changes") {
                        ForEach(changes) { change in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(change.field)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack {
                                    if !change.oldValue.isEmpty && change.oldValue != "(new)" {
                                        Text(change.oldValue)
                                            .strikethrough()
                                            .foregroundColor(.red)
                                    }

                                    if change.newValue != "(removed)" {
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        Text(change.newValue)
                                            .foregroundColor(.green)
                                    } else {
                                        Text("(removed)")
                                            .foregroundColor(.red)
                                            .italic()
                                    }
                                }
                                .font(.subheadline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        onApply()
                    } label: {
                        Label("Apply Updates", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        onSkip()
                    } label: {
                        Text("Add as New Contact")
                            .font(.subheadline)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

struct ReceivedContactRow: View {
    let contact: ReceivedContact

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with update badge
            ZStack(alignment: .topTrailing) {
                if let photoData = contact.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }

                // Update badge
                if contact.hasUnreadUpdate {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .offset(x: 2, y: -2)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contact.displayNameWithLocalized)
                        .font(.headline)

                    if contact.hasUnreadUpdate {
                        Text("Updated")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }

                // Show company with localized version if available
                if let company = contact.company {
                    if let localizedCompany = contact.localizedCompany {
                        Text("\(company) (\(localizedCompany))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let localizedCompany = contact.localizedCompany {
                    Text(localizedCompany)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    if contact.hasUnreadUpdate, let lastUpdated = contact.lastUpdatedAt {
                        Text("Updated \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Text(contact.receivedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Status indicators
            HStack(spacing: 8) {
                if contact.isTracked {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                if contact.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
                if contact.isImportedToContacts {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ReceivedContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let contact: ReceivedContact
    @State private var showingImportAlert = false
    @State private var importError: String?
    @State private var showingAccountPicker = false
    @State private var availableContainers: [ContactContainer] = []
    @State private var isLoadingContainers = false
    @State private var showingTagEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Update banner
                    if contact.hasUnreadUpdate {
                        UpdateBanner(contact: contact)
                            .padding(.horizontal)
                            .padding(.top)
                    }

                    // Card image if available
                    if let cardImageData = contact.cardImageData,
                       let uiImage = UIImage(data: cardImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 5)
                            .padding(.horizontal)
                            .padding(.top, contact.hasUnreadUpdate ? 0 : 16)
                    }

                    // Header
                    VStack(spacing: 12) {
                        if contact.cardImageData == nil {
                            // Only show avatar if no card image
                            if let photoData = contact.photoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.gray)
                            }
                        }

                        // Show both name versions
                        Text(contact.displayName)
                            .font(.title)
                            .fontWeight(.bold)

                        if let localizedName = contact.localizedFullName,
                           !contact.fullName.isEmpty {
                            Text(localizedName)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        // Title with localized version
                        if let title = contact.title {
                            if let localizedTitle = contact.localizedTitle, localizedTitle != title {
                                Text("\(title) (\(localizedTitle))")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(title)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let localizedTitle = contact.localizedTitle {
                            Text(localizedTitle)
                                .foregroundStyle(.secondary)
                        }

                        // Company with localized version
                        if let company = contact.company {
                            if let localizedCompany = contact.localizedCompany, localizedCompany != company {
                                Text("\(company) (\(localizedCompany))")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(company)
                                    .foregroundStyle(.secondary)
                            }
                        } else if let localizedCompany = contact.localizedCompany {
                            Text(localizedCompany)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, contact.cardImageData == nil ? 16 : 0)

                    // Contact actions
                    HStack(spacing: 24) {
                        if let phone = contact.phone {
                            ContactActionButton(icon: "phone.fill", title: "Call") {
                                if let url = URL(string: "tel:\(phone)") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        if let email = contact.email {
                            ContactActionButton(icon: "envelope.fill", title: "Email") {
                                if let url = URL(string: "mailto:\(email)") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }

                        if let website = contact.website {
                            ContactActionButton(icon: "globe", title: "Web") {
                                if let url = URL(string: website) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Import button
                    if !contact.isImportedToContacts {
                        Button {
                            loadContainersAndShowPicker()
                        } label: {
                            HStack {
                                if isLoadingContainers {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Label("Add to Contacts", systemImage: "person.badge.plus")
                                }
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoadingContainers)
                        .padding(.horizontal)
                    } else {
                        Label("Added to Contacts", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 16) {
                        if let phone = contact.phone {
                            DetailRow(icon: "phone.fill", label: "Phone", value: phone)
                        }
                        if let email = contact.email {
                            DetailRow(icon: "envelope.fill", label: "Email", value: email)
                        }
                        if let website = contact.website {
                            DetailRow(icon: "globe", label: "Website", value: website)
                        }

                        // Custom fields
                        ForEach(contact.customFields) { field in
                            DetailRow(icon: field.type.icon, label: field.label, value: field.value)
                        }

                        if let event = contact.receivedEvent {
                            DetailRow(icon: "calendar", label: "Event", value: event)
                        }
                        if let location = contact.receivedLocation {
                            DetailRow(icon: "location.fill", label: "Location", value: location)
                        }
                        if let notes = contact.notes, !notes.isEmpty {
                            DetailRow(icon: "note.text", label: "Notes", value: notes)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Track updates toggle
                    VStack(spacing: 12) {
                        Toggle(isOn: Binding(
                            get: { contact.isTracked },
                            set: { contact.isTracked = $0 }
                        )) {
                            Label("Track Updates", systemImage: "bell.fill")
                        }
                        .tint(.blue)

                        Text("Get notified when this contact updates their card")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Tags section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Tags", systemImage: "tag.fill")
                                .font(.headline)
                            Spacer()
                            Button {
                                showingTagEditor = true
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                        }

                        if contact.tags.isEmpty {
                            Text("No tags added")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(contact.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(TagService.shared.color(for: tag).opacity(0.15))
                                        .foregroundColor(TagService.shared.color(for: tag))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Version info
                    if contact.senderCardVersion > 1 {
                        Text("Card version \(contact.senderCardVersion)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Mark as read when dismissing
                        if contact.hasUnreadUpdate {
                            contact.markUpdateAsRead()
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        contact.isFavorite.toggle()
                    } label: {
                        Image(systemName: contact.isFavorite ? "star.fill" : "star")
                            .foregroundColor(contact.isFavorite ? .yellow : .gray)
                    }
                }
            }
            .alert("Import Error", isPresented: .init(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
            .sheet(isPresented: $showingAccountPicker) {
                AccountPickerSheet(
                    containers: availableContainers,
                    contact: contact
                ) { success in
                    if success {
                        contact.isImportedToContacts = true
                    }
                }
            }
            .sheet(isPresented: $showingTagEditor) {
                TagEditorView(contact: contact)
            }
        }
    }

    private func loadContainersAndShowPicker() {
        isLoadingContainers = true
        Task {
            do {
                let containers = try await ContactsService.shared.fetchContainers()
                await MainActor.run {
                    availableContainers = containers
                    isLoadingContainers = false
                    if containers.count == 1 {
                        // Only one account, import directly
                        importToContainer(containers[0].id)
                    } else if containers.isEmpty {
                        // No accounts found, use default
                        importToContainer(nil)
                    } else {
                        // Multiple accounts, show picker
                        showingAccountPicker = true
                    }
                }
            } catch {
                await MainActor.run {
                    isLoadingContainers = false
                    importError = error.localizedDescription
                }
            }
        }
    }

    private func importToContainer(_ containerId: String?) {
        Task {
            do {
                try await ContactsService.shared.importContact(contact, toContainer: containerId)
                await MainActor.run {
                    contact.isImportedToContacts = true
                }
            } catch {
                await MainActor.run {
                    importError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Account Picker Sheet

struct AccountPickerSheet: View {
    let containers: [ContactContainer]
    let contact: ReceivedContact
    let onComplete: (Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(containers) { container in
                        Button {
                            importToAccount(container.id)
                        } label: {
                            HStack {
                                Image(systemName: container.iconName)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 32)

                                Text(container.displayName)
                                    .foregroundColor(.primary)

                                Spacer()

                                if isImporting {
                                    ProgressView()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(isImporting)
                    }
                } header: {
                    Text("Choose Account")
                } footer: {
                    Text("Select where to save \(contact.displayName)")
                }
            }
            .navigationTitle("Add to Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Import Error", isPresented: .init(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") { importError = nil }
            } message: {
                Text(importError ?? "")
            }
        }
    }

    private func importToAccount(_ containerId: String) {
        isImporting = true
        Task {
            do {
                try await ContactsService.shared.importContact(contact, toContainer: containerId)
                await MainActor.run {
                    onComplete(true)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    importError = error.localizedDescription
                }
            }
        }
    }
}

struct ContactActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .frame(width: 50, height: 50)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .clipShape(Circle())

                Text(title)
                    .font(.caption)
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
        }
    }
}

// MARK: - Update Banner

struct UpdateBanner: View {
    let contact: ReceivedContact
    @State private var showingChanges = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Card Updated")
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let lastUpdated = contact.lastUpdatedAt {
                        Text(lastUpdated.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button {
                    contact.markUpdateAsRead()
                } label: {
                    Text("Dismiss")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
            }

            Text("This contact has updated their information. The latest version is shown below.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Card Update Service

class CardUpdateService {
    static let shared = CardUpdateService()

    private init() {}

    /// Check if a new contact matches an existing tracked contact
    func findExistingContact(
        for newContact: ReceivedContact,
        in existingContacts: [ReceivedContact]
    ) -> ReceivedContact? {
        // First, try to match by senderCardId (most reliable)
        if let senderCardId = newContact.senderCardId {
            if let existing = existingContacts.first(where: { $0.senderCardId == senderCardId }) {
                return existing
            }
        }

        // Then, try to match by email (unique identifier)
        if let email = newContact.email, !email.isEmpty {
            if let existing = existingContacts.first(where: { $0.email == email && $0.isTracked }) {
                return existing
            }
        }

        // Finally, try to match by phone
        if let phone = newContact.phone, !phone.isEmpty {
            let normalizedPhone = normalizePhone(phone)
            if let existing = existingContacts.first(where: {
                $0.isTracked && normalizePhone($0.phone ?? "") == normalizedPhone
            }) {
                return existing
            }
        }

        return nil
    }

    /// Normalize phone number for comparison
    private func normalizePhone(_ phone: String) -> String {
        phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }

    /// Check if new contact has updates compared to existing
    func hasUpdates(new: ReceivedContact, existing: ReceivedContact) -> Bool {
        // Check if version is newer
        if new.senderCardVersion > existing.senderCardVersion {
            return true
        }

        // Check if any fields changed
        return !existing.detectChanges(from: new).isEmpty
    }
}

// MARK: - Scanned Card Data

struct ScannedCardData: Identifiable {
    let id = UUID()
    let cardImageData: Data
    let ocrInfo: OCRService.ContactInfo?
}

// MARK: - Document Scanner for Received Cards

import VisionKit

struct DocumentScannerForReceived: UIViewControllerRepresentable {
    let onScan: (Data, OCRService.ContactInfo?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScannerForReceived

        init(_ parent: DocumentScannerForReceived) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.dismiss()

            guard scan.pageCount > 0 else { return }

            let image = scan.imageOfPage(at: 0)
            guard let imageData = image.jpegData(compressionQuality: 0.9) else { return }

            // Run OCR on the scanned image
            Task {
                let ocrInfo = try? await OCRService.shared.recognizeText(from: imageData)
                await MainActor.run {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.parent.onScan(imageData, ocrInfo)
                    }
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.dismiss()
        }
    }
}

// MARK: - QR Code Scanner

import AVFoundation

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onScan: (ReceivedContact) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QRScannerDelegate {
        let parent: QRCodeScannerView

        init(_ parent: QRCodeScannerView) {
            self.parent = parent
        }

        func didScanQRCode(_ code: String) {
            // Try to parse as vCard
            if let contact = parseVCard(code) {
                parent.onScan(contact)
                parent.dismiss()
            }
        }

        func didCancel() {
            parent.dismiss()
        }

        private func parseVCard(_ string: String) -> ReceivedContact? {
            // Basic vCard parsing
            guard string.contains("BEGIN:VCARD") else { return nil }

            var firstName = ""
            var lastName = ""
            var company: String?
            var title: String?
            var phone: String?
            var email: String?
            var website: String?

            let lines = string.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("N:") {
                    let parts = line.dropFirst(2).components(separatedBy: ";")
                    if parts.count >= 2 {
                        lastName = parts[0]
                        firstName = parts[1]
                    }
                } else if line.hasPrefix("FN:") {
                    let fullName = String(line.dropFirst(3))
                    let parts = fullName.components(separatedBy: " ")
                    if parts.count >= 2 {
                        firstName = parts[0]
                        lastName = parts.dropFirst().joined(separator: " ")
                    } else {
                        firstName = fullName
                    }
                } else if line.hasPrefix("ORG:") {
                    company = String(line.dropFirst(4))
                } else if line.hasPrefix("TITLE:") {
                    title = String(line.dropFirst(6))
                } else if line.hasPrefix("TEL") {
                    if let colonIndex = line.firstIndex(of: ":") {
                        phone = String(line[line.index(after: colonIndex)...])
                    }
                } else if line.hasPrefix("EMAIL") {
                    if let colonIndex = line.firstIndex(of: ":") {
                        email = String(line[line.index(after: colonIndex)...])
                    }
                } else if line.hasPrefix("URL:") {
                    website = String(line.dropFirst(4))
                }
            }

            guard !firstName.isEmpty || !lastName.isEmpty else { return nil }

            return ReceivedContact(
                firstName: firstName,
                lastName: lastName,
                company: company,
                title: title,
                phone: phone,
                email: email,
                website: website
            )
        }
    }
}

protocol QRScannerDelegate: AnyObject {
    func didScanQRCode(_ code: String)
    func didCancel()
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              session.canAddInput(videoInput) else {
            return
        }

        session.addInput(videoInput)

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        self.captureSession = session
        self.previewLayer = previewLayer
    }

    private func setupUI() {
        // Scan frame overlay
        let scanFrame = UIView()
        scanFrame.layer.borderColor = UIColor.white.cgColor
        scanFrame.layer.borderWidth = 2
        scanFrame.layer.cornerRadius = 12
        scanFrame.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanFrame)

        NSLayoutConstraint.activate([
            scanFrame.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanFrame.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            scanFrame.widthAnchor.constraint(equalToConstant: 250),
            scanFrame.heightAnchor.constraint(equalToConstant: 250)
        ])

        // Instructions label
        let label = UILabel()
        label.text = "Point at QR code"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: scanFrame.bottomAnchor, constant: 24)
        ])

        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }

    @objc private func cancelTapped() {
        delegate?.didCancel()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = metadataObject.stringValue else { return }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didScanQRCode(stringValue)
    }
}

// MARK: - Received Contact Editor

struct ReceivedContactEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let existingContact: ReceivedContact?
    let cardImageData: Data?
    let ocrInfo: OCRService.ContactInfo?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var localizedFirstName = ""
    @State private var localizedLastName = ""
    @State private var company = ""
    @State private var localizedCompany = ""
    @State private var title = ""
    @State private var localizedTitle = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var notes = ""
    @State private var receivedEvent = ""
    @State private var receivedLocation = ""

    var isEditing: Bool { existingContact != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Card image preview
                if let imageData = cardImageData,
                   let uiImage = UIImage(data: imageData) {
                    Section {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section("Name (English)") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                Section("Name (中文/日文)") {
                    TextField("姓", text: $localizedLastName)
                    TextField("名", text: $localizedFirstName)
                }

                Section("Work (English)") {
                    TextField("Company", text: $company)
                        .textContentType(.organizationName)
                    TextField("Title", text: $title)
                        .textContentType(.jobTitle)
                }

                Section("Work (中文/日文)") {
                    TextField("公司名稱", text: $localizedCompany)
                    TextField("職稱", text: $localizedTitle)
                }

                Section("Contact") {
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Website", text: $website)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                Section("Context") {
                    TextField("Event (e.g., CES 2025)", text: $receivedEvent)
                    TextField("Location", text: $receivedLocation)
                        .textContentType(.location)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Contact" : "New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveContact()
                    }
                    .disabled(firstName.isEmpty && lastName.isEmpty)
                }
            }
            .onAppear {
                loadData()
            }
        }
    }

    private func loadData() {
        // Load from existing contact if editing
        if let contact = existingContact {
            firstName = contact.firstName
            lastName = contact.lastName
            localizedFirstName = contact.localizedFirstName ?? ""
            localizedLastName = contact.localizedLastName ?? ""
            company = contact.company ?? ""
            localizedCompany = contact.localizedCompany ?? ""
            title = contact.title ?? ""
            localizedTitle = contact.localizedTitle ?? ""
            phone = contact.phone ?? ""
            email = contact.email ?? ""
            website = contact.website ?? ""
            notes = contact.notes ?? ""
            receivedEvent = contact.receivedEvent ?? ""
            receivedLocation = contact.receivedLocation ?? ""
        }
        // Apply OCR results if available
        else if let ocr = ocrInfo {
            if let fn = ocr.firstName { firstName = fn }
            if let ln = ocr.lastName { lastName = ln }
            if let lfn = ocr.localizedFirstName { localizedFirstName = lfn }
            if let lln = ocr.localizedLastName { localizedLastName = lln }
            if let c = ocr.company { company = c }
            if let lc = ocr.localizedCompany { localizedCompany = lc }
            if let t = ocr.title { title = t }
            if let lt = ocr.localizedTitle { localizedTitle = lt }
            if let p = ocr.phone { phone = p }
            if let e = ocr.email { email = e }
            if let w = ocr.website { website = w }
        }
    }

    private func saveContact() {
        if let contact = existingContact {
            // Update existing
            contact.firstName = firstName
            contact.lastName = lastName
            contact.localizedFirstName = localizedFirstName.isEmpty ? nil : localizedFirstName
            contact.localizedLastName = localizedLastName.isEmpty ? nil : localizedLastName
            contact.company = company.isEmpty ? nil : company
            contact.localizedCompany = localizedCompany.isEmpty ? nil : localizedCompany
            contact.title = title.isEmpty ? nil : title
            contact.localizedTitle = localizedTitle.isEmpty ? nil : localizedTitle
            contact.phone = phone.isEmpty ? nil : phone
            contact.email = email.isEmpty ? nil : email
            contact.website = website.isEmpty ? nil : website
            contact.notes = notes.isEmpty ? nil : notes
            contact.receivedEvent = receivedEvent.isEmpty ? nil : receivedEvent
            contact.receivedLocation = receivedLocation.isEmpty ? nil : receivedLocation
        } else {
            // Create new
            let contact = ReceivedContact(
                firstName: firstName,
                lastName: lastName,
                localizedFirstName: localizedFirstName.isEmpty ? nil : localizedFirstName,
                localizedLastName: localizedLastName.isEmpty ? nil : localizedLastName,
                company: company.isEmpty ? nil : company,
                localizedCompany: localizedCompany.isEmpty ? nil : localizedCompany,
                title: title.isEmpty ? nil : title,
                localizedTitle: localizedTitle.isEmpty ? nil : localizedTitle,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                website: website.isEmpty ? nil : website,
                cardImageData: cardImageData,
                receivedLocation: receivedLocation.isEmpty ? nil : receivedLocation,
                receivedEvent: receivedEvent.isEmpty ? nil : receivedEvent,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(contact)
        }

        dismiss()
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color : color.opacity(0.15))
                .foregroundColor(isSelected ? .white : color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Editor View

struct TagEditorView: View {
    @Bindable var contact: ReceivedContact
    @Environment(\.dismiss) private var dismiss
    @State private var newTag = ""

    var suggestedTags: [String] {
        TagService.shared.getUnusedSuggestedTags(existingTags: contact.tags)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Current tags
                Section("Current Tags") {
                    if contact.tags.isEmpty {
                        Text("No tags")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contact.tags, id: \.self) { tag in
                            HStack {
                                Circle()
                                    .fill(TagService.shared.color(for: tag))
                                    .frame(width: 12, height: 12)
                                Text(tag)
                                Spacer()
                                Button {
                                    removeTag(tag)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Add new tag
                Section("Add Tag") {
                    HStack {
                        TextField("New tag name", text: $newTag)
                        Button("Add") {
                            addTag(newTag)
                            newTag = ""
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                // Suggested tags
                if !suggestedTags.isEmpty {
                    Section("Suggestions") {
                        FlowLayout(spacing: 8) {
                            ForEach(suggestedTags, id: \.self) { tag in
                                Button {
                                    addTag(tag)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.caption)
                                        Text(tag)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(TagService.shared.color(for: tag).opacity(0.15))
                                    .foregroundColor(TagService.shared.color(for: tag))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !contact.tags.contains(trimmed) else { return }
        contact.tags.append(trimmed)
    }

    private func removeTag(_ tag: String) {
        contact.tags.removeAll { $0 == tag }
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + lineHeight
        }
    }
}

#Preview {
    ReceivedCardsView()
        .modelContainer(for: ReceivedContact.self, inMemory: true)
}
