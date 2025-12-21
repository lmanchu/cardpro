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
        var localizedFirstName: String?  // CJK name (中文/日文)
        var localizedLastName: String?
        var company: String?
        var localizedCompany: String?
        var title: String?
        var localizedTitle: String?
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

                // Extract candidates with confidence filtering
                var strings: [String] = []
                for observation in observations {
                    // Get multiple candidates and pick the best one
                    let candidates = observation.topCandidates(3)
                    if let best = candidates.first(where: { candidate in
                        // Prefer candidates without garbled symbols
                        let hasGarbled = candidate.string.contains(where: { char in
                            let scalar = char.unicodeScalars.first?.value ?? 0
                            // Filter out control characters and weird symbols
                            return scalar < 0x20 || (0x2400...0x243F).contains(scalar)
                        })
                        return !hasGarbled && candidate.confidence > 0.3
                    }) ?? candidates.first {
                        strings.append(best.string)
                    }
                }

                continuation.resume(returning: strings)
            }

            // Configure recognition for best CJK support
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            // Use automatic language detection for better multilingual support
            if #available(iOS 16.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            request.recognitionLanguages = languages

            // Minimum text height for better accuracy (filter out noise)
            request.minimumTextHeight = 0.02

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

        // First pass: extract clearly identifiable fields (email, phone, website)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if info.email == nil, let email = extractEmail(from: trimmed) {
                info.email = email
            }
            if info.phone == nil, let phone = extractPhone(from: trimmed) {
                info.phone = phone
            }
            if info.website == nil, let website = extractWebsite(from: trimmed) {
                info.website = website
            }
        }

        // Get remaining lines (not email/phone/website)
        let remainingLines = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            // Skip if this line is primarily contact info
            if extractEmail(from: trimmed) != nil { return nil }
            if extractPhone(from: trimmed) != nil { return nil }
            if extractWebsite(from: trimmed) != nil { return nil }
            // Skip address-like lines
            if isLikelyAddress(trimmed) { return nil }
            return trimmed
        }

        // Classify each line
        var candidates: [(line: String, type: LineType, score: Int)] = []

        for line in remainingLines {
            let companyScore = scoreAsCompany(line)
            let nameScore = scoreAsPersonName(line)
            let titleScore = scoreAsTitle(line)

            // Determine the most likely type
            let maxScore = max(companyScore, nameScore, titleScore)
            if maxScore > 0 {
                if companyScore == maxScore {
                    candidates.append((line, .company, companyScore))
                } else if nameScore == maxScore {
                    candidates.append((line, .name, nameScore))
                } else {
                    candidates.append((line, .title, titleScore))
                }
            }
        }

        // Sort by score and assign
        let sortedCandidates = candidates.sorted { $0.score > $1.score }

        for candidate in sortedCandidates {
            switch candidate.type {
            case .name:
                if info.firstName == nil {
                    let parsed = parseName(candidate.line)
                    info.firstName = parsed.firstName
                    info.lastName = parsed.lastName
                    info.localizedFirstName = parsed.localizedFirstName
                    info.localizedLastName = parsed.localizedLastName
                }
            case .company:
                if info.company == nil {
                    let parsed = parseCompany(candidate.line)
                    info.company = parsed.company
                    info.localizedCompany = parsed.localizedCompany
                }
            case .title:
                if info.title == nil {
                    let parsed = parseTitle(candidate.line)
                    info.title = parsed.title
                    info.localizedTitle = parsed.localizedTitle
                }
            }
        }

        return info
    }

    private enum LineType {
        case name, company, title
    }

    /// Score how likely a line is a company name (0-100)
    private func scoreAsCompany(_ text: String) -> Int {
        var score = 0

        // Company suffixes (strong indicators)
        let companySuffixes = [
            "Inc", "Inc.", "LLC", "Ltd", "Ltd.", "Corp", "Corp.", "Co.", "Co",
            "Corporation", "Company", "Limited", "Group", "Holdings",
            "有限公司", "股份有限公司", "集團", "企業", "科技", "技術", "網路", "數位",
            "株式会社", "合同会社", "有限会社",
            "GmbH", "AG", "S.A.", "B.V.", "Pty"
        ]

        for suffix in companySuffixes {
            if text.localizedCaseInsensitiveContains(suffix) {
                score += 80
                break
            }
        }

        // Industry keywords (medium indicators)
        let industryKeywords = [
            "Technology", "Tech", "Software", "Digital", "Media", "Capital",
            "Ventures", "Partners", "Solutions", "Services", "Consulting",
            "Bank", "Insurance", "Finance", "Investment",
            "科技", "軟體", "顧問", "金融", "投資", "銀行", "保險"
        ]

        for keyword in industryKeywords {
            if text.localizedCaseInsensitiveContains(keyword) {
                score += 30
                break
            }
        }

        // Length heuristic: company names tend to be longer
        if text.count > 10 {
            score += 10
        }

        // Contains all caps words (often company abbreviations)
        let words = text.split(separator: " ")
        if words.contains(where: { $0.count >= 2 && $0.uppercased() == String($0) && $0.allSatisfy { $0.isLetter } }) {
            score += 15
        }

        return min(score, 100)
    }

    /// Score how likely a line is a person's name (0-100)
    private func scoreAsPersonName(_ text: String) -> Int {
        var score = 0
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if primarily CJK
        let cjkCount = trimmed.filter { $0.isCJK }.count
        let letterCount = trimmed.filter { $0.isLetter }.count

        if letterCount == 0 { return 0 }

        let isCJK = cjkCount > letterCount / 2

        if isCJK {
            // CJK name heuristics
            let charCount = trimmed.filter { !$0.isWhitespace }.count

            // Typical CJK names are 2-4 characters
            if charCount >= 2 && charCount <= 4 {
                score += 60
            } else if charCount == 5 {
                score += 30  // Could be name with title
            }

            // No numbers or special symbols in names
            if !trimmed.contains(where: { $0.isNumber || ["@", ".", "-", "/"].contains(String($0)) }) {
                score += 20
            }

            // Common Chinese surnames boost
            let commonSurnames = ["王", "李", "張", "劉", "陳", "楊", "黃", "趙", "周", "吳",
                                 "林", "郭", "何", "高", "羅", "鄭", "朱", "許", "謝", "宋"]
            if let firstChar = trimmed.first, commonSurnames.contains(String(firstChar)) {
                score += 20
            }
        } else {
            // Western name heuristics
            let words = trimmed.split(separator: " ")

            // Typical names are 2-3 words
            if words.count >= 2 && words.count <= 4 {
                score += 50
            }

            // First letter of each word is capitalized (title case)
            let titleCaseCount = words.filter { word in
                guard let first = word.first else { return false }
                return first.isUppercase && word.dropFirst().allSatisfy { $0.isLowercase || !$0.isLetter }
            }.count

            if titleCaseCount == words.count {
                score += 30
            }

            // No company suffixes
            let companySuffixes = ["Inc", "LLC", "Ltd", "Corp", "Co"]
            if !companySuffixes.contains(where: { trimmed.localizedCaseInsensitiveContains($0) }) {
                score += 10
            }
        }

        // Penalty for being too long (likely not just a name)
        if trimmed.count > 30 {
            score -= 30
        }

        return max(0, min(score, 100))
    }

    /// Score how likely a line is a job title (0-100)
    private func scoreAsTitle(_ text: String) -> Int {
        var score = 0

        let titleKeywords = [
            // English
            "CEO", "CTO", "CFO", "COO", "CMO", "CIO", "CISO",
            "President", "Vice President", "VP",
            "Director", "Manager", "Lead", "Head", "Chief",
            "Engineer", "Developer", "Designer", "Architect",
            "Founder", "Co-Founder", "Partner", "Principal",
            "Analyst", "Consultant", "Specialist", "Coordinator",
            "Executive", "Officer", "Administrator",
            // Chinese
            "執行長", "技術長", "財務長", "營運長",
            "總經理", "副總經理", "協理", "經理", "副理",
            "總監", "主任", "主管", "組長",
            "董事長", "董事", "創辦人", "共同創辦人",
            "工程師", "設計師", "分析師", "顧問",
            // Japanese
            "社長", "副社長", "専務", "常務",
            "部長", "次長", "課長", "係長", "主任",
            "取締役", "代表"
        ]

        for keyword in titleKeywords {
            if text.localizedCaseInsensitiveContains(keyword) {
                score += 70
                break
            }
        }

        // Title-like patterns
        if text.contains(" of ") || text.contains(" at ") {
            score += 20
        }

        // Typically shorter than company names
        if text.count < 40 && text.count > 3 {
            score += 10
        }

        return min(score, 100)
    }

    /// Check if a line looks like an address
    private func isLikelyAddress(_ text: String) -> Bool {
        let addressKeywords = [
            "Street", "St.", "Avenue", "Ave.", "Road", "Rd.", "Floor", "F.",
            "Building", "Bldg", "Suite", "Room", "Tower",
            "路", "街", "巷", "弄", "號", "樓", "室", "大樓", "大廈",
            "丁目", "番地", "階"
        ]
        return addressKeywords.contains { text.localizedCaseInsensitiveContains($0) }
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

    /// Parse name into first/last and localized first/last
    /// Handles Western names (First Last), CJK names (姓名), and bilingual names (林辰陽 Hagry Lin)
    private func parseName(_ text: String) -> (firstName: String?, lastName: String?, localizedFirstName: String?, localizedLastName: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract CJK and Western parts
        let words = trimmed.split(separator: " ")
        var westernWords: [String] = []
        var cjkChars = ""

        for word in words {
            let wordStr = String(word)
            if wordStr.contains(where: { $0.isCJK }) {
                cjkChars += wordStr
            } else if wordStr.allSatisfy({ $0.isLetter }) {
                westernWords.append(wordStr)
            }
        }

        var firstName: String?
        var lastName: String?
        var localizedFirstName: String?
        var localizedLastName: String?

        // Parse Western name
        if westernWords.count >= 2 {
            firstName = westernWords[0]
            lastName = westernWords.dropFirst().joined(separator: " ")
        } else if westernWords.count == 1 {
            firstName = westernWords[0]
        }

        // Parse CJK name
        if !cjkChars.isEmpty {
            let chars = Array(cjkChars)
            if chars.count >= 2 {
                // Common double-character surnames
                let doubleSurnames = ["歐陽", "司馬", "上官", "諸葛", "司徒", "東方", "西門", "南宮"]
                let firstTwo = String(chars.prefix(2))

                if doubleSurnames.contains(firstTwo) && chars.count > 2 {
                    localizedFirstName = String(chars.dropFirst(2))
                    localizedLastName = firstTwo
                } else {
                    localizedFirstName = String(chars.dropFirst(1))
                    localizedLastName = String(chars.first!)
                }
            } else if chars.count == 1 {
                localizedLastName = String(chars[0])
            }
        }

        // If no Western name but has CJK, use CJK as primary
        if firstName == nil && lastName == nil {
            if let locFirst = localizedFirstName {
                firstName = locFirst
            }
            if let locLast = localizedLastName {
                lastName = locLast
            }
            // Clear localized since we're using them as primary
            localizedFirstName = nil
            localizedLastName = nil
        }

        return (firstName, lastName, localizedFirstName, localizedLastName)
    }

    /// Parse company name - extract both Western and CJK versions
    private func parseCompany(_ text: String) -> (company: String?, localizedCompany: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if mixed
        let cjkChars = trimmed.filter { $0.isCJK }
        let latinChars = trimmed.filter { $0.isLetter && !$0.isCJK }

        if !cjkChars.isEmpty && !latinChars.isEmpty {
            // Mixed - try to separate
            // Usually format is "公司中文名" or "English Name 中文名"
            var western = ""
            var cjk = ""

            for char in trimmed {
                if char.isCJK {
                    cjk.append(char)
                } else {
                    western.append(char)
                }
            }

            return (western.trimmingCharacters(in: .whitespaces),
                    cjk.trimmingCharacters(in: .whitespaces))
        } else if !cjkChars.isEmpty {
            return (nil, trimmed)
        } else {
            return (trimmed, nil)
        }
    }

    /// Parse title - extract both Western and CJK versions
    private func parseTitle(_ text: String) -> (title: String?, localizedTitle: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let cjkPart = trimmed.filter { $0.isCJK }
        let latinPart = trimmed.filter { $0.isLetter && !$0.isCJK }

        if !cjkPart.isEmpty && !latinPart.isEmpty {
            // Split by common patterns like "董事長 Chairman"
            let parts = trimmed.components(separatedBy: CharacterSet.whitespaces)
            var western: [String] = []
            var cjk: [String] = []

            for part in parts {
                if part.contains(where: { $0.isCJK }) {
                    cjk.append(part)
                } else if !part.isEmpty {
                    western.append(part)
                }
            }

            return (western.joined(separator: " "), cjk.joined())
        } else if !cjkPart.isEmpty {
            return (nil, trimmed)
        } else {
            return (trimmed, nil)
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
