import Vision
import UIKit

/// Service for OCR text recognition on business cards
/// Supports English, Chinese (Simplified/Traditional), and Japanese
class OCRService {
    static let shared = OCRService()

    private init() {}

    /// Recognized contact information from a business card
    struct ContactInfo {
        var firstName: String?
        var lastName: String?
        var company: String?
        var title: String?
        var phone: String?
        var email: String?
        var website: String?
        var rawText: String  // All recognized text for reference
    }

    /// Recognize text from an image
    /// - Parameters:
    ///   - imageData: The image data to process
    ///   - languages: Language codes to recognize (default: en, zh-Hans, zh-Hant, ja)
    /// - Returns: ContactInfo with parsed fields
    func recognizeText(from imageData: Data, languages: [String] = ["en", "zh-Hans", "zh-Hant", "ja"]) async throws -> ContactInfo {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        // Perform text recognition
        let recognizedStrings = try await performTextRecognition(on: cgImage, languages: languages)
        let rawText = recognizedStrings.joined(separator: "\n")

        // Parse contact info from recognized text
        return parseContactInfo(from: recognizedStrings, rawText: rawText)
    }

    /// Perform Vision text recognition
    private func performTextRecognition(on cgImage: CGImage, languages: [String]) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // Extract top candidates from each observation
                let strings = observations.compactMap { observation -> String? in
                    observation.topCandidates(1).first?.string
                }

                continuation.resume(returning: strings)
            }

            // Configure recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages

            // Perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Parse contact information from recognized text lines
    private func parseContactInfo(from lines: [String], rawText: String) -> ContactInfo {
        var info = ContactInfo(rawText: rawText)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Check for email
            if info.email == nil, let email = extractEmail(from: trimmed) {
                info.email = email
                continue
            }

            // Check for phone number
            if info.phone == nil, let phone = extractPhone(from: trimmed) {
                info.phone = phone
                continue
            }

            // Check for website
            if info.website == nil, let website = extractWebsite(from: trimmed) {
                info.website = website
                continue
            }
        }

        // Try to extract name and company from remaining lines
        let nonContactLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty &&
                   extractEmail(from: trimmed) == nil &&
                   extractPhone(from: trimmed) == nil &&
                   extractWebsite(from: trimmed) == nil
        }

        // Heuristics for name and company
        // Usually the first prominent line is the name
        // Company often follows or is in a different style
        if let nameLine = nonContactLines.first {
            let parsed = parseName(nameLine)
            info.firstName = parsed.firstName
            info.lastName = parsed.lastName
        }

        // Look for company and title in remaining lines
        for (index, line) in nonContactLines.enumerated() {
            if index == 0 { continue } // Skip name line

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Common title keywords
            let titleKeywords = ["CEO", "CTO", "CFO", "COO", "Manager", "Director", "Engineer", "Designer",
                                "Founder", "President", "VP", "Vice President", "Lead", "Head",
                                "總經理", "經理", "執行長", "董事", "主任", "工程師", "設計師",
                                "社長", "部長", "課長", "係長", "主任"]

            let isLikelyTitle = titleKeywords.contains { trimmed.localizedCaseInsensitiveContains($0) }

            if isLikelyTitle && info.title == nil {
                info.title = trimmed
            } else if info.company == nil && !isLikelyTitle {
                // Likely company name
                info.company = trimmed
            }
        }

        return info
    }

    // MARK: - Field Extraction

    /// Extract email from text
    private func extractEmail(from text: String) -> String? {
        let pattern = #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        return String(text[range]).lowercased()
    }

    /// Extract phone number from text
    private func extractPhone(from text: String) -> String? {
        // Match various phone formats including:
        // +886-912-345-678, (02) 2345-6789, 0912345678, +81-3-1234-5678
        let patterns = [
            #"\+?\d{1,4}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,4}[-.\s]?\d{0,4}"#,
            #"\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{3,4}"#,
            #"(?:TEL|Tel|tel|電話|Phone|phone|携帯|mobile)[:\s]*([+\d\-\s\(\)]+)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                let phone = String(text[range])
                // Validate it looks like a phone (at least 7 digits)
                let digits = phone.filter { $0.isNumber }
                if digits.count >= 7 {
                    return phone.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }

    /// Extract website from text
    private func extractWebsite(from text: String) -> String? {
        let patterns = [
            #"(?:https?://)?(?:www\.)?[A-Za-z0-9][A-Za-z0-9.-]+\.[A-Za-z]{2,}(?:/[^\s]*)?"#,
            #"(?:URL|Web|Website|HP|ホームページ|網站)[:\s]*([\w.-]+\.[A-Za-z]{2,}[^\s]*)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                var website = String(text[range])
                // Skip if it's actually an email
                if website.contains("@") { continue }
                // Add https:// if missing
                if !website.lowercased().hasPrefix("http") {
                    website = "https://" + website
                }
                return website
            }
        }
        return nil
    }

    /// Parse name into first and last name
    /// Handles Western names (First Last) and CJK names (姓名)
    private func parseName(_ text: String) -> (firstName: String?, lastName: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's primarily CJK characters
        let cjkCount = trimmed.filter { $0.isCJK }.count
        let totalCount = trimmed.filter { !$0.isWhitespace }.count

        if cjkCount > totalCount / 2 {
            // CJK name: typically 姓(1-2 chars) + 名(1-2 chars)
            // For Chinese/Japanese, family name comes first
            let chars = Array(trimmed.filter { !$0.isWhitespace })
            if chars.count >= 2 {
                // Common double-character surnames
                let doubleSurnames = ["歐陽", "司馬", "上官", "諸葛", "司徒", "東方", "西門", "南宮"]
                let firstTwo = String(chars.prefix(2))

                if doubleSurnames.contains(firstTwo) && chars.count > 2 {
                    return (firstName: String(chars.dropFirst(2)), lastName: firstTwo)
                } else {
                    return (firstName: String(chars.dropFirst(1)), lastName: String(chars.first!))
                }
            }
            return (firstName: trimmed, lastName: nil)
        } else {
            // Western name: First Last
            let parts = trimmed.split(separator: " ", maxSplits: 1)
            if parts.count >= 2 {
                return (firstName: String(parts[0]), lastName: String(parts[1]))
            }
            return (firstName: trimmed, lastName: nil)
        }
    }
}

// MARK: - Character Extension

private extension Character {
    /// Check if character is CJK (Chinese, Japanese, Korean)
    var isCJK: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        // CJK Unified Ideographs and extensions
        return (0x4E00...0x9FFF).contains(scalar.value) ||    // CJK Unified
               (0x3400...0x4DBF).contains(scalar.value) ||    // CJK Extension A
               (0x20000...0x2A6DF).contains(scalar.value) ||  // CJK Extension B
               (0x3040...0x309F).contains(scalar.value) ||    // Hiragana
               (0x30A0...0x30FF).contains(scalar.value) ||    // Katakana
               (0xAC00...0xD7AF).contains(scalar.value)       // Korean Hangul
    }
}

// MARK: - Errors

enum OCRError: LocalizedError {
    case invalidImage
    case recognitionFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Could not process the image"
        case .recognitionFailed:
            return "Text recognition failed"
        }
    }
}
