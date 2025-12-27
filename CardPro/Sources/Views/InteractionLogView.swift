import SwiftUI
import SwiftData

// MARK: - Interaction Log View

struct InteractionLogView: View {
    let contact: ReceivedContact
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddInteraction = false

    private var interactions: [Interaction] {
        CRMService.shared.fetchInteractions(for: contact, modelContext: modelContext)
    }

    var body: some View {
        List {
            // Stats section
            Section {
                HStack {
                    StatBox(
                        title: "Total",
                        value: "\(contact.interactionCount)",
                        icon: "chart.bar.fill",
                        color: .blue
                    )

                    StatBox(
                        title: "Score",
                        value: "\(Int(contact.relationshipScore))",
                        icon: contact.relationshipLevel.icon,
                        color: Color(hex: contact.relationshipLevel.color) ?? .gray
                    )

                    StatBox(
                        title: "Level",
                        value: contact.relationshipLevel.rawValue,
                        icon: "star.fill",
                        color: Color(hex: contact.relationshipLevel.color) ?? .gray
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Interactions list
            Section("Recent Interactions") {
                if interactions.isEmpty {
                    ContentUnavailableView(
                        "No Interactions",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Log your first interaction with \(contact.displayName)")
                    )
                } else {
                    ForEach(interactions) { interaction in
                        InteractionRow(interaction: interaction)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteInteraction(interaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Interactions")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddInteraction = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddInteraction) {
            AddInteractionSheet(contact: contact)
        }
    }

    private func deleteInteraction(_ interaction: Interaction) {
        Task {
            try? await CRMService.shared.deleteInteraction(interaction, modelContext: modelContext)
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Interaction Row

struct InteractionRow: View {
    let interaction: Interaction

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: interaction.type.icon)
                .font(.title3)
                .foregroundColor(interaction.type.color)
                .frame(width: 36, height: 36)
                .background(interaction.type.color.opacity(0.15))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(interaction.displayTitle)
                        .font(.headline)

                    if let duration = interaction.formattedDuration {
                        Text("(\(duration))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let notes = interaction.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(interaction.formattedTimestamp)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Interaction Sheet

struct AddInteractionSheet: View {
    let contact: ReceivedContact
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedType: InteractionType = .note
    @State private var title = ""
    @State private var notes = ""
    @State private var timestamp = Date()
    @State private var durationMinutes: Int?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                // Type picker
                Section("Type") {
                    Picker("Interaction Type", selection: $selectedType) {
                        ForEach(InteractionType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                // Details
                Section("Details") {
                    TextField("Title (optional)", text: $title)

                    if selectedType == .call || selectedType == .meeting {
                        HStack {
                            Text("Duration")
                            Spacer()
                            TextField("min", value: $durationMinutes, format: .number)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .textFieldStyle(.roundedBorder)
                            Text("minutes")
                                .foregroundStyle(.secondary)
                        }
                    }

                    DatePicker("Date & Time", selection: $timestamp)
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Log Interaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveInteraction()
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func saveInteraction() {
        isSaving = true

        Task {
            _ = try await CRMService.shared.logInteraction(
                for: contact,
                type: selectedType,
                title: title.isEmpty ? nil : title,
                notes: notes.isEmpty ? nil : notes,
                timestamp: timestamp,
                durationMinutes: durationMinutes,
                modelContext: modelContext
            )

            dismiss()
        }
    }
}

// MARK: - Relationship Score View

struct RelationshipScoreView: View {
    let score: Double

    private var level: RelationshipLevel {
        switch score {
        case 0..<20: return .cold
        case 20..<40: return .warm
        case 40..<60: return .active
        case 60..<80: return .strong
        default: return .vip
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Score circle
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        Color(hex: level.color) ?? .blue,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(score))")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            .frame(width: 60, height: 60)

            // Level info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: level.icon)
                        .foregroundColor(Color(hex: level.color) ?? .gray)
                    Text(level.rawValue)
                        .font(.headline)
                }

                Text("Relationship Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        InteractionLogView(contact: ReceivedContact(
            firstName: "John",
            lastName: "Doe",
            company: "Acme Inc"
        ))
    }
    .modelContainer(for: [ReceivedContact.self, Interaction.self], inMemory: true)
}
