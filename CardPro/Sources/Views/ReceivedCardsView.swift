import SwiftUI
import SwiftData

struct ReceivedCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ReceivedContact.receivedAt, order: .reverse) private var contacts: [ReceivedContact]
    @State private var searchText = ""
    @State private var selectedContact: ReceivedContact?

    var filteredContacts: [ReceivedContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.displayName.localizedCaseInsensitiveContains(searchText) ||
            (contact.company?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (contact.email?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
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
                    List {
                        ForEach(filteredContacts) { contact in
                            ReceivedContactRow(contact: contact)
                                .onTapGesture {
                                    selectedContact = contact
                                }
                        }
                        .onDelete(perform: deleteContacts)
                    }
                    .searchable(text: $searchText, prompt: "Search contacts")
                }
            }
            .navigationTitle("Received")
            .sheet(item: $selectedContact) { contact in
                ReceivedContactDetailView(contact: contact)
            }
        }
    }

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredContacts[index])
        }
    }
}

struct ReceivedContactRow: View {
    let contact: ReceivedContact

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
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

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.displayName)
                    .font(.headline)

                if let company = contact.company {
                    Text(company)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(contact.receivedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Status indicators
            HStack(spacing: 8) {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
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

                        Text(contact.displayName)
                            .font(.title)
                            .fontWeight(.bold)

                        if let title = contact.title {
                            Text(title)
                                .foregroundStyle(.secondary)
                        }

                        if let company = contact.company {
                            Text(company)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top)

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
                            importToContacts()
                        } label: {
                            Label("Add to Contacts", systemImage: "person.badge.plus")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
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
        }
    }

    private func importToContacts() {
        // TODO: Implement actual contact import using Contacts framework
        contact.isImportedToContacts = true
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

#Preview {
    ReceivedCardsView()
        .modelContainer(for: ReceivedContact.self, inMemory: true)
}
