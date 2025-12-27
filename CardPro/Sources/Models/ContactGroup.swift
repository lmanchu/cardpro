import Foundation
import SwiftData
import SwiftUI

// MARK: - Contact Group Model

@Model
final class ContactGroup {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#007AFF"  // Default blue
    var iconName: String?             // SF Symbol name
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // Firebase sync
    var firebaseId: String?           // Firebase document ID
    var needsSync: Bool = true        // Whether needs to sync to Firebase

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String = "#007AFF",
        iconName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.firebaseId = nil
        self.needsSync = true
    }

    // MARK: - Color Helpers

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    static let defaultColors: [(name: String, hex: String)] = [
        ("Blue", "#007AFF"),
        ("Green", "#34C759"),
        ("Orange", "#FF9500"),
        ("Red", "#FF3B30"),
        ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Teal", "#5AC8FA"),
        ("Yellow", "#FFCC00"),
        ("Gray", "#8E8E93"),
        ("Brown", "#A2845E"),
    ]

    static let defaultIcons: [String] = [
        "folder.fill",
        "person.2.fill",
        "briefcase.fill",
        "building.2.fill",
        "star.fill",
        "heart.fill",
        "flag.fill",
        "tag.fill",
        "bookmark.fill",
        "bolt.fill",
    ]
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#007AFF"
        }

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Firebase Contact Group

struct FirebaseContactGroup: Codable, Identifiable {
    var id: String?
    var userId: String
    var name: String
    var colorHex: String
    var iconName: String?
    var createdAt: Date
    var updatedAt: Date

    init(from group: ContactGroup, userId: String) {
        self.id = group.firebaseId
        self.userId = userId
        self.name = group.name
        self.colorHex = group.colorHex
        self.iconName = group.iconName
        self.createdAt = group.createdAt
        self.updatedAt = group.updatedAt
    }
}
