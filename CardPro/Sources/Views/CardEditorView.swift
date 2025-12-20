import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct CardEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let card: BusinessCard?

    // Basic info
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var title = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var website = ""
    @State private var notes = ""

    // Custom fields
    @State private var customFields: [CustomField] = []
    @State private var showingAddFieldSheet = false
    @State private var editingFieldIndex: Int?

    // Photos
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Card image
    @State private var cardImageData: Data?
    @State private var cardImageSource: String?
    @State private var selectedCardImageItem: PhotosPickerItem?
    @State private var showingCardImageOptions = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingTemplateSelector = false
    @State private var selectedTemplate: CardImageGenerator.Template = .modern

    // OCR
    @State private var isProcessingOCR = false
    @State private var showingOCRResults = false
    @State private var ocrContactInfo: OCRService.ContactInfo?
    @State private var ocrError: String?

    var isEditing: Bool { card != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Profile photo section
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
                } header: {
                    Text("Profile Photo")
                }

                // Card image section - 儀式感的關鍵！
                Section {
                    if let cardImageData,
                       let uiImage = UIImage(data: cardImageData) {
                        // Show existing card image
                        VStack(spacing: 12) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(radius: 4)
                                .allowsHitTesting(false) // Allow scroll gestures to pass through

                            HStack {
                                if let source = cardImageSource {
                                    Label(
                                        source == "scan" ? "Scanned" :
                                        source == "upload" ? "Uploaded" : "Generated",
                                        systemImage: source == "scan" ? "camera.fill" :
                                                    source == "upload" ? "photo.fill" : "wand.and.stars"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Change") {
                                    showingCardImageOptions = true
                                }
                                .font(.caption)
                            }
                        }
                    } else {
                        // No card image yet
                        Button {
                            showingCardImageOptions = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Add Card Design")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text("Scan, upload, or generate")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("Card Design")
                } footer: {
                    Text("This image will be shared along with your contact info for a more personal touch.")
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

                // Custom fields section
                Section {
                    ForEach(Array(customFields.enumerated()), id: \.element.id) { index, field in
                        HStack {
                            Image(systemName: field.type.icon)
                                .foregroundColor(.accentColor)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(field.value)
                                    .font(.body)
                            }

                            Spacer()

                            Button {
                                editingFieldIndex = index
                                showingAddFieldSheet = true
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .contentShape(Rectangle())
                    }
                    .onDelete { indexSet in
                        customFields.remove(atOffsets: indexSet)
                    }

                    Button {
                        editingFieldIndex = nil
                        showingAddFieldSheet = true
                    } label: {
                        Label("Add Field", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Additional Info")
                } footer: {
                    Text("Add social media, extra phones, or custom fields.")
                }

                // Notes section
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Preview section
                Section("Preview") {
                    if let cardImageData, let uiImage = UIImage(data: cardImageData) {
                        // Show card image as preview
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 5)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } else {
                        // Show generated preview
                        CardPreviewView(card: previewCard)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
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
            .onChange(of: selectedCardImageItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        cardImageData = data
                        cardImageSource = "upload"
                        // Run OCR on uploaded image
                        await processOCR(imageData: data)
                    }
                }
            }
            .onChange(of: cardImageData) { oldValue, newValue in
                // Run OCR when card image changes from camera scan
                if let data = newValue, oldValue == nil, cardImageSource == "scan" {
                    Task {
                        await processOCR(imageData: data)
                    }
                }
            }
            .onAppear {
                loadCard()
            }
            .confirmationDialog("Card Design", isPresented: $showingCardImageOptions) {
                // Only show camera option if camera is available (not on simulator)
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Scan Physical Card", systemImage: "camera.fill")
                    }
                }

                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Upload from Photos", systemImage: "photo.fill")
                }

                Button {
                    showingTemplateSelector = true
                } label: {
                    Label("Generate from Template", systemImage: "wand.and.stars")
                }

                if cardImageData != nil {
                    Button("Remove Card Design", role: .destructive) {
                        cardImageData = nil
                        cardImageSource = nil
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedCardImageItem, matching: .images)
            .sheet(isPresented: $showingCamera) {
                CameraPicker(imageData: $cardImageData, source: $cardImageSource)
            }
            .sheet(isPresented: $showingTemplateSelector) {
                TemplateSelector(
                    card: previewCard,
                    selectedTemplate: $selectedTemplate,
                    cardImageData: $cardImageData,
                    cardImageSource: $cardImageSource
                )
            }
            .sheet(isPresented: $showingOCRResults) {
                OCRResultsSheet(
                    contactInfo: ocrContactInfo,
                    onApply: { info in
                        applyOCRResults(info)
                        showingOCRResults = false
                    },
                    onCancel: {
                        showingOCRResults = false
                    }
                )
            }
            .sheet(isPresented: $showingAddFieldSheet) {
                CustomFieldEditorSheet(
                    field: editingFieldIndex.map { customFields[$0] },
                    onSave: { field in
                        if let index = editingFieldIndex {
                            customFields[index] = field
                        } else {
                            customFields.append(field)
                        }
                        showingAddFieldSheet = false
                        editingFieldIndex = nil
                    },
                    onDelete: editingFieldIndex.map { index in
                        {
                            customFields.remove(at: index)
                            showingAddFieldSheet = false
                            editingFieldIndex = nil
                        }
                    },
                    onCancel: {
                        showingAddFieldSheet = false
                        editingFieldIndex = nil
                    }
                )
            }
            .overlay {
                if isProcessingOCR {
                    ZStack {
                        Color.black.opacity(0.4)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Scanning card...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .ignoresSafeArea()
                }
            }
            .alert("OCR Error", isPresented: .init(
                get: { ocrError != nil },
                set: { if !$0 { ocrError = nil } }
            )) {
                Button("OK") { ocrError = nil }
            } message: {
                Text(ocrError ?? "Unknown error")
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
            cardImageData: cardImageData,
            cardImageSource: cardImageSource,
            notes: notes.isEmpty ? nil : notes,
            customFields: customFields
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
        customFields = card.customFields
        photoData = card.photoData
        cardImageData = card.cardImageData
        cardImageSource = card.cardImageSource
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
            card.customFields = customFields
            card.photoData = photoData
            card.cardImageData = cardImageData
            card.cardImageSource = cardImageSource
            card.incrementVersion() // Increment version on update
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
                cardImageData: cardImageData,
                cardImageSource: cardImageSource,
                notes: notes.isEmpty ? nil : notes,
                customFields: customFields,
                isDefault: true
            )
            modelContext.insert(newCard)
        }

        dismiss()
    }

    // MARK: - OCR

    @MainActor
    private func processOCR(imageData: Data) async {
        isProcessingOCR = true

        do {
            let result = try await OCRService.shared.recognizeText(from: imageData)
            ocrContactInfo = result

            // Only show results if we found something useful
            if result.firstName != nil || result.email != nil || result.phone != nil || result.company != nil {
                showingOCRResults = true
            }
        } catch {
            ocrError = error.localizedDescription
        }

        isProcessingOCR = false
    }

    private func applyOCRResults(_ info: OCRService.ContactInfo) {
        // Only fill empty fields (don't overwrite existing data)
        if firstName.isEmpty, let fn = info.firstName {
            firstName = fn
        }
        if lastName.isEmpty, let ln = info.lastName {
            lastName = ln
        }
        if company.isEmpty, let comp = info.company {
            company = comp
        }
        if title.isEmpty, let t = info.title {
            title = t
        }
        if phone.isEmpty, let p = info.phone {
            phone = p
        }
        if email.isEmpty, let e = info.email {
            email = e
        }
        if website.isEmpty, let w = info.website {
            website = w
        }
    }
}

// MARK: - OCR Results Sheet

struct OCRResultsSheet: View {
    let contactInfo: OCRService.ContactInfo?
    let onApply: (OCRService.ContactInfo) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let info = contactInfo {
                    Section("Detected Information") {
                        if let firstName = info.firstName {
                            LabeledContent("First Name", value: firstName)
                        }
                        if let lastName = info.lastName {
                            LabeledContent("Last Name", value: lastName)
                        }
                        if let company = info.company {
                            LabeledContent("Company", value: company)
                        }
                        if let title = info.title {
                            LabeledContent("Title", value: title)
                        }
                        if let phone = info.phone {
                            LabeledContent("Phone", value: phone)
                        }
                        if let email = info.email {
                            LabeledContent("Email", value: email)
                        }
                        if let website = info.website {
                            LabeledContent("Website", value: website)
                        }
                    }

                    Section("Raw Text") {
                        Text(info.rawText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No text detected")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("OCR Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Auto-Fill") {
                        if let info = contactInfo {
                            onApply(info)
                        }
                    }
                    .disabled(contactInfo == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Binding var source: String?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.9)
                parent.source = "scan"
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Template Selector

struct TemplateSelector: View {
    let card: BusinessCard
    @Binding var selectedTemplate: CardImageGenerator.Template
    @Binding var cardImageData: Data?
    @Binding var cardImageSource: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose a Template")
                        .font(.headline)
                        .padding(.top)

                    ForEach(CardImageGenerator.Template.allCases, id: \.self) { template in
                        VStack(spacing: 8) {
                            CardTemplateView(card: card, template: template)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedTemplate == template ? Color.accentColor : Color.clear, lineWidth: 3)
                                )
                                .shadow(radius: 4)
                                .onTapGesture {
                                    selectedTemplate = template
                                }

                            Text(template.rawValue)
                                .font(.subheadline)
                                .foregroundColor(selectedTemplate == template ? .accentColor : .secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Template") {
                        generateAndSave()
                    }
                }
            }
        }
    }

    private func generateAndSave() {
        Task { @MainActor in
            if let data = CardImageGenerator.shared.generateImageData(for: card, template: selectedTemplate) {
                cardImageData = data
                cardImageSource = "generated"
            }
            dismiss()
        }
    }
}

// MARK: - Custom Field Editor Sheet

struct CustomFieldEditorSheet: View {
    let field: CustomField?
    let onSave: (CustomField) -> Void
    let onDelete: (() -> Void)?
    let onCancel: () -> Void

    @State private var label = ""
    @State private var value = ""
    @State private var fieldType: CustomField.FieldType = .social
    @State private var showingPresets = false

    var isEditing: Bool { field != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Presets section (only for new fields)
                if !isEditing {
                    Section {
                        Button {
                            showingPresets = true
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Choose from Presets")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Quick Add")
                    }
                }

                // Field details
                Section {
                    TextField("Label (e.g., LinkedIn)", text: $label)
                        .textInputAutocapitalization(.words)

                    Picker("Type", selection: $fieldType) {
                        ForEach(CustomField.FieldType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                } header: {
                    Text("Field Info")
                }

                Section {
                    TextField(placeholderForType, text: $value)
                        .keyboardType(keyboardTypeForType)
                        .textInputAutocapitalization(capitalizationForType)
                } header: {
                    Text("Value")
                }

                // Delete button (only for editing)
                if let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Field")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Field" : "Add Field")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newField = CustomField(
                            id: field?.id ?? UUID(),
                            label: label,
                            value: value,
                            type: fieldType
                        )
                        onSave(newField)
                    }
                    .disabled(label.isEmpty || value.isEmpty)
                }
            }
            .onAppear {
                if let field {
                    label = field.label
                    value = field.value
                    fieldType = field.type
                }
            }
            .sheet(isPresented: $showingPresets) {
                PresetPickerSheet(
                    onSelect: { preset in
                        label = preset.label
                        fieldType = preset.type
                        showingPresets = false
                    },
                    onCancel: {
                        showingPresets = false
                    }
                )
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var placeholderForType: String {
        switch fieldType {
        case .phone: return "+886-912-345-678"
        case .email: return "email@example.com"
        case .url: return "https://..."
        case .social: return "Username or URL"
        case .text: return "Value"
        }
    }

    private var keyboardTypeForType: UIKeyboardType {
        switch fieldType {
        case .phone: return .phonePad
        case .email: return .emailAddress
        case .url: return .URL
        case .social, .text: return .default
        }
    }

    private var capitalizationForType: TextInputAutocapitalization {
        switch fieldType {
        case .phone, .email, .url, .social: return .never
        case .text: return .sentences
        }
    }
}

// MARK: - Preset Picker Sheet

struct PresetPickerSheet: View {
    let onSelect: ((label: String, type: CustomField.FieldType)) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Social Media") {
                    ForEach(CustomField.presets.filter { $0.type == .social }, id: \.label) { preset in
                        Button {
                            onSelect(preset)
                        } label: {
                            Label(preset.label, systemImage: preset.type.icon)
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section("Phone") {
                    ForEach(CustomField.presets.filter { $0.type == .phone }, id: \.label) { preset in
                        Button {
                            onSelect(preset)
                        } label: {
                            Label(preset.label, systemImage: preset.type.icon)
                        }
                        .foregroundColor(.primary)
                    }
                }

                Section("Other") {
                    ForEach(CustomField.presets.filter { $0.type == .text }, id: \.label) { preset in
                        Button {
                            onSelect(preset)
                        } label: {
                            Label(preset.label, systemImage: preset.type.icon)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Choose Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    CardEditorView(card: nil)
        .modelContainer(for: BusinessCard.self, inMemory: true)
}
