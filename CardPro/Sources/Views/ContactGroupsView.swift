import SwiftUI
import SwiftData

// MARK: - Contact Groups View

struct ContactGroupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ContactGroup.name) private var groups: [ContactGroup]
    @State private var showingAddGroup = false
    @State private var groupToEdit: ContactGroup?
    @State private var groupToDelete: ContactGroup?
    @State private var showingDeleteConfirm = false

    var body: some View {
        List {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No Groups",
                    systemImage: "folder.badge.plus",
                    description: Text("Create groups to organize your contacts")
                )
            } else {
                ForEach(groups) { group in
                    GroupRow(group: group)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            groupToEdit = group
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                groupToDelete = group
                                showingDeleteConfirm = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .navigationTitle("Groups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddGroup = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddGroup) {
            GroupEditorSheet(group: nil)
        }
        .sheet(item: $groupToEdit) { group in
            GroupEditorSheet(group: group)
        }
        .alert("Delete Group", isPresented: $showingDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                groupToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let group = groupToDelete {
                    deleteGroup(group)
                }
            }
        } message: {
            if let group = groupToDelete {
                Text("Are you sure you want to delete \"\(group.name)\"? Contacts in this group will not be deleted.")
            }
        }
    }

    private func deleteGroup(_ group: ContactGroup) {
        Task {
            try? await CRMService.shared.deleteGroup(group, modelContext: modelContext)
        }
        groupToDelete = nil
    }
}

// MARK: - Group Row

struct GroupRow: View {
    let group: ContactGroup
    @Environment(\.modelContext) private var modelContext

    private var contactCount: Int {
        CRMService.shared.fetchContacts(in: group, modelContext: modelContext).count
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: group.iconName ?? "folder.fill")
                .font(.title2)
                .foregroundColor(group.color)
                .frame(width: 40, height: 40)
                .background(group.color.opacity(0.15))
                .clipShape(Circle())

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.headline)

                Text("\(contactCount) contacts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Group Editor Sheet

struct GroupEditorSheet: View {
    let group: ContactGroup?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var selectedColorHex: String = "#007AFF"
    @State private var selectedIconName: String? = "folder.fill"
    @State private var isSaving = false

    private var isEditing: Bool { group != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section("Name") {
                    TextField("Group name", text: $name)
                }

                // Color
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(ContactGroup.defaultColors, id: \.hex) { color in
                            Circle()
                                .fill(Color(hex: color.hex) ?? .blue)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if selectedColorHex == color.hex {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                    }
                                }
                                .onTapGesture {
                                    selectedColorHex = color.hex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Icon
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(ContactGroup.defaultIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(selectedIconName == icon ? .white : Color(hex: selectedColorHex) ?? .blue)
                                .frame(width: 44, height: 44)
                                .background(
                                    selectedIconName == icon
                                        ? (Color(hex: selectedColorHex) ?? .blue)
                                        : Color(.systemGray5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedIconName = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isEditing ? "Edit Group" : "New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGroup()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onAppear {
                if let group = group {
                    name = group.name
                    selectedColorHex = group.colorHex
                    selectedIconName = group.iconName
                }
            }
        }
    }

    private func saveGroup() {
        isSaving = true

        Task {
            if let group = group {
                // Update existing
                group.name = name
                group.colorHex = selectedColorHex
                group.iconName = selectedIconName
                group.updatedAt = Date()
                group.needsSync = true
            } else {
                // Create new
                _ = try await CRMService.shared.createGroup(
                    name: name,
                    colorHex: selectedColorHex,
                    iconName: selectedIconName,
                    modelContext: modelContext
                )
            }

            dismiss()
        }
    }
}

// MARK: - Group Picker

struct GroupPicker: View {
    let contact: ReceivedContact
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ContactGroup.name) private var groups: [ContactGroup]

    var body: some View {
        Section("Groups") {
            if groups.isEmpty {
                HStack {
                    Text("No groups created")
                        .foregroundStyle(.secondary)
                    Spacer()
                    NavigationLink {
                        ContactGroupsView()
                    } label: {
                        Text("Manage")
                            .font(.caption)
                    }
                }
            } else {
                ForEach(groups) { group in
                    GroupToggleRow(contact: contact, group: group)
                }
            }
        }
    }
}

struct GroupToggleRow: View {
    let contact: ReceivedContact
    let group: ContactGroup

    private var isInGroup: Bool {
        contact.groupIds.contains(group.id)
    }

    var body: some View {
        Button {
            toggleGroup()
        } label: {
            HStack {
                Image(systemName: group.iconName ?? "folder.fill")
                    .foregroundColor(group.color)

                Text(group.name)
                    .foregroundColor(.primary)

                Spacer()

                if isInGroup {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    private func toggleGroup() {
        if isInGroup {
            CRMService.shared.removeContact(contact, from: group)
        } else {
            CRMService.shared.addContact(contact, to: group)
        }
    }
}

#Preview {
    NavigationStack {
        ContactGroupsView()
    }
    .modelContainer(for: [ContactGroup.self, ReceivedContact.self], inMemory: true)
}
