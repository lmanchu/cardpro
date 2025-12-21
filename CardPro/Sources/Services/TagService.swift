import Foundation
import SwiftUI

/// Service for managing contact tags
class TagService {
    static let shared = TagService()

    private let userDefaultsKey = "ContactTags"

    /// Predefined tag suggestions
    let suggestedTags = [
        "Work",
        "Personal",
        "Client",
        "Partner",
        "Vendor",
        "Conference",
        "Networking",
        "VIP",
        "Follow Up"
    ]

    /// Tag colors for visual differentiation
    let tagColors: [String: Color] = [
        "Work": .blue,
        "Personal": .green,
        "Client": .orange,
        "Partner": .purple,
        "Vendor": .brown,
        "Conference": .pink,
        "Networking": .cyan,
        "VIP": .yellow,
        "Follow Up": .red
    ]

    private init() {}

    /// Get color for a tag (default to gray if not predefined)
    func color(for tag: String) -> Color {
        tagColors[tag] ?? .gray
    }

    /// Get all tags used by contacts
    func getAllTags(from contacts: [ReceivedContact]) -> [String] {
        var allTags = Set<String>()
        for contact in contacts {
            for tag in contact.tags {
                allTags.insert(tag)
            }
        }
        return Array(allTags).sorted()
    }

    /// Get suggested tags that haven't been used yet
    func getUnusedSuggestedTags(existingTags: [String]) -> [String] {
        suggestedTags.filter { !existingTags.contains($0) }
    }
}
