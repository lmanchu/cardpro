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
    @State private var showingDocumentScanner = false
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingTemplateSelector = false
    @State private var selectedTemplate: CardImageGenerator.Template = .modern

    // OCR
    @State private var isProcessingOCR = false
    @State private var showingOCRResults = false
    @State private var ocrContactInfo: OCRService.ContactInfo?
    @State private var ocrError: String?

    // Cropping - use a wrapper struct for sheet(item:) pattern
    @State private var cropRequest: CropRequest?

    var isEditing: Bool { card != nil }

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle(isEditing ? "Edit Card" : "New Card")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
                .onAppear { loadCard() }
                .onChange(of: selectedPhotoItem) { _, newItem in
                    handlePhotoSelection(newItem)
                }
                .onChange(of: selectedCardImageItem) { _, newItem in
                    handleCardImageSelection(newItem)
                }
        }
        .confirmationDialog("Card Design", isPresented: $showingCardImageOptions) {
            cardImageDialogButtons
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedCardImageItem, matching: .images)
        .sheet(isPresented: $showingDocumentScanner) {
            DocumentScanner { imageData in
                // Document scanner already crops the image
                cardImageData = imageData
                cardImageSource = "scan"
                Task {
                    await processOCR(imageData: imageData)
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { imageData in
                // Regular camera - go through cropper for manual crop
                cropRequest = CropRequest(imageData: imageData, source: "scan")
            }
        }
        .sheet(item: $cropRequest) { request in
            ImageCropperView(
                imageData: request.imageData,
                onCrop: { croppedData in
                    cardImageData = croppedData
                    cardImageSource = request.source
                    cropRequest = nil
                    Task {
                        await processOCR(imageData: croppedData)
                    }
                },
                onCancel: {
                    cropRequest = nil
                }
            )
        }
        .sheet(isPresented: $showingTemplateSelector) {
            templateSelectorSheet
        }
        .sheet(isPresented: $showingOCRResults) {
            ocrResultsSheet
        }
        .sheet(isPresented: $showingAddFieldSheet) {
            customFieldSheet
        }
        .overlay { ocrOverlay }
        .alert("OCR Error", isPresented: .init(
            get: { ocrError != nil },
            set: { if !$0 { ocrError = nil } }
        )) {
            Button("OK") { ocrError = nil }
        } message: {
            Text(ocrError ?? "Unknown error")
        }
    }

    // MARK: - Form Content

    @ViewBuilder
    private var formContent: some View {
        Form {
            profilePhotoSection
            cardImageSection
            nameSection
            localizedNameSection
            workSection
            localizedWorkSection
            contactSection
            customFieldsSection
            notesSection
            previewSection
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var profilePhotoSection: some View {
        Section {
            HStack {
                Spacer()
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    profilePhotoView
                }
                Spacer()
            }
            .listRowBackground(Color.clear)
        } header: {
            Text("Profile Photo")
        }
    }

    @ViewBuilder
    private var profilePhotoView: some View {
        if let photoData, let uiImage = UIImage(data: photoData) {
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

    @ViewBuilder
    private var cardImageSection: some View {
        Section {
            if let cardImageData, let uiImage = UIImage(data: cardImageData) {
                existingCardImageView(uiImage: uiImage)
            } else {
                addCardImageButton
            }
        } header: {
            Text("Card Design")
        } footer: {
            Text("This image will be shared along with your contact info for a more personal touch.")
        }
    }

    @ViewBuilder
    private func existingCardImageView(uiImage: UIImage) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(radius: 4)
                .allowsHitTesting(false)

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
    }

    @ViewBuilder
    private var addCardImageButton: some View {
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

    @ViewBuilder
    private var nameSection: some View {
        Section("Name (English)") {
            TextField("First Name", text: $firstName)
                .textContentType(.givenName)
            TextField("Last Name", text: $lastName)
                .textContentType(.familyName)
        }
    }

    @ViewBuilder
    private var localizedNameSection: some View {
        Section("Name (中文/日文)") {
            TextField("姓", text: $localizedLastName)
            TextField("名", text: $localizedFirstName)
        }
    }

    @ViewBuilder
    private var workSection: some View {
        Section("Work (English)") {
            TextField("Company", text: $company)
                .textContentType(.organizationName)
            TextField("Title", text: $title)
                .textContentType(.jobTitle)
        }
    }

    @ViewBuilder
    private var localizedWorkSection: some View {
        Section("Work (中文/日文)") {
            TextField("公司名稱", text: $localizedCompany)
            TextField("職稱", text: $localizedTitle)
        }
    }

    @ViewBuilder
    private var contactSection: some View {
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
    }

    @ViewBuilder
    private var customFieldsSection: some View {
        Section {
            ForEach(Array(customFields.enumerated()), id: \.element.id) { index, field in
                customFieldRow(index: index, field: field)
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
    }

    @ViewBuilder
    private func customFieldRow(index: Int, field: CustomField) -> some View {
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

    @ViewBuilder
    private var notesSection: some View {
        Section("Notes") {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        Section("Preview") {
            if let cardImageData, let uiImage = UIImage(data: cardImageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 5)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } else {
                CardPreviewView(card: previewCard)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                dismiss()
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveCard()
            }
            .disabled(firstName.isEmpty && lastName.isEmpty && localizedFirstName.isEmpty && localizedLastName.isEmpty)
        }
    }

    // MARK: - Dialog Buttons

    @ViewBuilder
    private var cardImageDialogButtons: some View {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            Button {
                showingDocumentScanner = true
            } label: {
                Label("Quick Scan (Auto Edge)", systemImage: "doc.viewfinder")
            }

            Button {
                showingCamera = true
            } label: {
                Label("HD Photo (Manual Crop)", systemImage: "camera.fill")
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

        if let existingData = cardImageData {
            Button {
                // Re-crop existing image
                cropRequest = CropRequest(imageData: existingData, source: cardImageSource ?? "scan")
            } label: {
                Label("Crop Current Image", systemImage: "crop")
            }

            Button("Remove Card Design", role: .destructive) {
                cardImageData = nil
                cardImageSource = nil
            }
        }

        Button("Cancel", role: .cancel) {}
    }

    // MARK: - Sheet Views

    @ViewBuilder
    private var templateSelectorSheet: some View {
        TemplateSelector(
            card: previewCard,
            selectedTemplate: $selectedTemplate,
            cardImageData: $cardImageData,
            cardImageSource: $cardImageSource
        )
    }

    @ViewBuilder
    private var ocrResultsSheet: some View {
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

    @ViewBuilder
    private var customFieldSheet: some View {
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

    // MARK: - OCR Overlay

    @ViewBuilder
    private var ocrOverlay: some View {
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

    // MARK: - Computed Properties

    private var previewCard: BusinessCard {
        BusinessCard(
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
            photoData: photoData,
            cardImageData: cardImageData,
            cardImageSource: cardImageSource,
            notes: notes.isEmpty ? nil : notes,
            customFields: customFields
        )
    }

    // MARK: - Event Handlers

    private func handlePhotoSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                photoData = data
            }
        }
    }

    private func handleCardImageSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                cropRequest = CropRequest(imageData: data, source: "upload")
            }
        }
    }

    // MARK: - Data Operations

    private func loadCard() {
        guard let card else { return }
        firstName = card.firstName
        lastName = card.lastName
        localizedFirstName = card.localizedFirstName ?? ""
        localizedLastName = card.localizedLastName ?? ""
        company = card.company ?? ""
        localizedCompany = card.localizedCompany ?? ""
        title = card.title ?? ""
        localizedTitle = card.localizedTitle ?? ""
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
            card.localizedFirstName = localizedFirstName.isEmpty ? nil : localizedFirstName
            card.localizedLastName = localizedLastName.isEmpty ? nil : localizedLastName
            card.company = company.isEmpty ? nil : company
            card.localizedCompany = localizedCompany.isEmpty ? nil : localizedCompany
            card.title = title.isEmpty ? nil : title
            card.localizedTitle = localizedTitle.isEmpty ? nil : localizedTitle
            card.phone = phone.isEmpty ? nil : phone
            card.email = email.isEmpty ? nil : email
            card.website = website.isEmpty ? nil : website
            card.notes = notes.isEmpty ? nil : notes
            card.customFields = customFields
            card.photoData = photoData
            card.cardImageData = cardImageData
            card.cardImageSource = cardImageSource
            card.incrementVersion()
        } else {
            // Create new
            let newCard = BusinessCard(
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

            if result.firstName != nil || result.email != nil || result.phone != nil || result.company != nil {
                showingOCRResults = true
            }
        } catch {
            ocrError = error.localizedDescription
        }

        isProcessingOCR = false
    }

    private func applyOCRResults(_ info: OCRService.ContactInfo) {
        if firstName.isEmpty, let fn = info.firstName {
            firstName = fn
        }
        if lastName.isEmpty, let ln = info.lastName {
            lastName = ln
        }
        if localizedFirstName.isEmpty, let lfn = info.localizedFirstName {
            localizedFirstName = lfn
        }
        if localizedLastName.isEmpty, let lln = info.localizedLastName {
            localizedLastName = lln
        }
        if company.isEmpty, let comp = info.company {
            company = comp
        }
        if localizedCompany.isEmpty, let lcomp = info.localizedCompany {
            localizedCompany = lcomp
        }
        if title.isEmpty, let t = info.title {
            title = t
        }
        if localizedTitle.isEmpty, let lt = info.localizedTitle {
            localizedTitle = lt
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
                    Section("Name (English)") {
                        if let firstName = info.firstName {
                            LabeledContent("First Name", value: firstName)
                        }
                        if let lastName = info.lastName {
                            LabeledContent("Last Name", value: lastName)
                        }
                    }

                    if info.localizedFirstName != nil || info.localizedLastName != nil {
                        Section("Name (中文/日文)") {
                            if let localizedLastName = info.localizedLastName {
                                LabeledContent("姓", value: localizedLastName)
                            }
                            if let localizedFirstName = info.localizedFirstName {
                                LabeledContent("名", value: localizedFirstName)
                            }
                        }
                    }

                    Section("Work") {
                        if let company = info.company {
                            LabeledContent("Company", value: company)
                        }
                        if let localizedCompany = info.localizedCompany {
                            LabeledContent("公司", value: localizedCompany)
                        }
                        if let title = info.title {
                            LabeledContent("Title", value: title)
                        }
                        if let localizedTitle = info.localizedTitle {
                            LabeledContent("職稱", value: localizedTitle)
                        }
                    }

                    Section("Contact") {
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

// MARK: - Crop Request

struct CropRequest: Identifiable {
    let id = UUID()
    let imageData: Data
    let source: String
}

// MARK: - Camera Picker (high quality, manual crop)

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
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
            parent.dismiss()
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.95) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.parent.onCapture(data)
                }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Document Scanner (auto edge detection)

import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    let onScan: (Data) -> Void
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
        let parent: DocumentScanner

        init(_ parent: DocumentScanner) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.dismiss()

            // Get the first scanned page (business card)
            guard scan.pageCount > 0 else { return }

            let image = scan.imageOfPage(at: 0)
            if let data = image.jpegData(compressionQuality: 0.9) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.parent.onScan(data)
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scan failed: \(error.localizedDescription)")
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
