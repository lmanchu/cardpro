import SwiftUI
import SwiftData

/// View shown when receiving a business card via AirDrop or file sharing
struct IncomingCardView: View {
    let contact: ReceivedContact
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.rectangle.badge.plus")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)

                    Text("New Business Card")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Someone shared their card with you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Contact preview card
                VStack(spacing: 16) {
                    // Card image if available
                    if let cardImageData = contact.cardImageData,
                       let uiImage = UIImage(data: cardImageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 5)
                    }
                    // Photo (avatar)
                    else if let photoData = contact.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                    }

                    // Name
                    VStack(spacing: 4) {
                        Text(contact.displayName)
                            .font(.title3)
                            .fontWeight(.semibold)

                        if let localizedName = contact.localizedFullName {
                            Text(localizedName)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }

                        if let title = contact.title, let company = contact.company {
                            Text("\(title) @ \(company)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if let company = contact.company {
                            Text(company)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Contact details
                VStack(alignment: .leading, spacing: 12) {
                    if let phone = contact.phone {
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text(phone)
                        }
                    }

                    if let email = contact.email {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(email)
                        }
                    }

                    if let website = contact.website {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text(website)
                                .lineLimit(1)
                        }
                    }

                    // Custom fields
                    ForEach(contact.customFields) { field in
                        HStack {
                            Image(systemName: field.type.icon)
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(field.label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(field.value)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Action buttons
                if showSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)

                        Text("Card Saved!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Button {
                            saveContact()
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                }
                                Text("Save to CardPro")
                            }
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isSaving)

                        Button {
                            dismissView()
                        } label: {
                            Text("Not Now")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Received Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismissView()
                    }
                }
            }
        }
    }

    private func saveContact() {
        isSaving = true

        // Set received time
        contact.receivedAt = Date()

        // Insert into model context
        modelContext.insert(contact)

        // Try to save
        do {
            try modelContext.save()
            showSuccess = true

            // Auto dismiss after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismissView()
            }
        } catch {
            print("Error saving contact: \(error)")
            isSaving = false
        }
    }

    private func dismissView() {
        dismiss()
        onDismiss()
    }
}

#Preview {
    IncomingCardView(
        contact: ReceivedContact(
            firstName: "Leo",
            lastName: "Man",
            company: "IrisGo",
            title: "CEO",
            phone: "+886 912 345 678",
            email: "leo@irisgo.xyz",
            website: "https://irisgo.xyz"
        ),
        onDismiss: {}
    )
    .modelContainer(for: ReceivedContact.self, inMemory: true)
}
