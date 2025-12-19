import SwiftUI
import SwiftData
import PhotosUI

struct CardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let card: BusinessCard?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var title = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var notes = ""
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?

    var isEditing: Bool { card != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Photo section
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            if let photoData,
                               let uiImage = UIImage(data: photoData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 100))
                                    .foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Name section
                Section("Name") {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                }

                // Work section
                Section("Work") {
                    TextField("Company", text: $company)
                        .textContentType(.organizationName)
                    TextField("Title", text: $title)
                        .textContentType(.jobTitle)
                }

                // Contact section
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

                // Notes section
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Preview section
                Section("Preview") {
                    CardPreviewView(card: previewCard)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(isEditing ? "Edit Card" : "New Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCard()
                    }
                    .disabled(firstName.isEmpty && lastName.isEmpty)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onAppear {
                loadCard()
            }
        }
    }

    private var previewCard: BusinessCard {
        BusinessCard(
            firstName: firstName,
            lastName: lastName,
            company: company.isEmpty ? nil : company,
            title: title.isEmpty ? nil : title,
            phone: phone.isEmpty ? nil : phone,
            email: email.isEmpty ? nil : email,
            website: website.isEmpty ? nil : website,
            photoData: photoData,
            notes: notes.isEmpty ? nil : notes
        )
    }

    private func loadCard() {
        guard let card else { return }
        firstName = card.firstName
        lastName = card.lastName
        company = card.company ?? ""
        title = card.title ?? ""
        phone = card.phone ?? ""
        email = card.email ?? ""
        website = card.website ?? ""
        notes = card.notes ?? ""
        photoData = card.photoData
    }

    private func saveCard() {
        if let card {
            // Update existing
            card.firstName = firstName
            card.lastName = lastName
            card.company = company.isEmpty ? nil : company
            card.title = title.isEmpty ? nil : title
            card.phone = phone.isEmpty ? nil : phone
            card.email = email.isEmpty ? nil : email
            card.website = website.isEmpty ? nil : website
            card.notes = notes.isEmpty ? nil : notes
            card.photoData = photoData
            card.updatedAt = Date()
        } else {
            // Create new
            let newCard = BusinessCard(
                firstName: firstName,
                lastName: lastName,
                company: company.isEmpty ? nil : company,
                title: title.isEmpty ? nil : title,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                website: website.isEmpty ? nil : website,
                photoData: photoData,
                notes: notes.isEmpty ? nil : notes,
                isDefault: true  // First card is default
            )
            modelContext.insert(newCard)
        }

        dismiss()
    }
}

#Preview {
    CardEditorView(card: nil)
        .modelContainer(for: BusinessCard.self, inMemory: true)
}
