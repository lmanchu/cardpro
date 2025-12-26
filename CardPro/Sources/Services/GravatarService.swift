import Foundation
import CryptoKit
import UIKit

/// Service for fetching Gravatar profile pictures based on email
class GravatarService {
    static let shared = GravatarService()

    private init() {}

    /// Cache for fetched images to avoid repeated network calls
    private var cache: [String: Data] = [:]

    /// Fetch Gravatar image for an email address
    /// - Parameters:
    ///   - email: The email address to look up
    ///   - size: The image size (default 200px)
    /// - Returns: Image data if found, nil if no Gravatar exists
    func fetchGravatar(for email: String, size: Int = 200) async -> Data? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else { return nil }

        // Check cache first
        if let cached = cache[trimmedEmail] {
            return cached
        }

        // Generate MD5 hash of email
        let hash = md5Hash(trimmedEmail)

        // Gravatar URL with d=404 to return 404 if no image exists
        let urlString = "https://gravatar.com/avatar/\(hash)?s=\(size)&d=404"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check if we got a valid image (not 404)
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                // Verify it's actually an image
                if UIImage(data: data) != nil {
                    cache[trimmedEmail] = data
                    return data
                }
            }

            return nil
        } catch {
            print("Gravatar fetch error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Generate MD5 hash of a string
    private func md5Hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    /// Clear the image cache
    func clearCache() {
        cache.removeAll()
    }

    /// Check if a Gravatar exists for an email (without downloading full image)
    func hasGravatar(for email: String) async -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedEmail.isEmpty else { return false }

        let hash = md5Hash(trimmedEmail)
        let urlString = "https://gravatar.com/avatar/\(hash)?d=404"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            return false
        }
    }
}
