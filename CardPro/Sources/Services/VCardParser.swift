import Foundation

/// Service for parsing vCard files into ReceivedContact
class VCardParser {
    static let shared = VCardParser()

    private init() {}

    /// Parse a vCard file URL into ReceivedContact
    func parseFile(at url: URL) -> ReceivedContact? {
        guard let vcardString = try? String(contentsOf: url, encoding: .utf8) else {
            // Try other encodings
            guard let data = try? Data(contentsOf: url),
                  let string = String(data: data, encoding: .isoLatin1) ?? String(data: data, encoding: .ascii) else {
                return nil
            }
            return parse(string)
        }
        return parse(vcardString)
    }

    /// Parse a vCard string into ReceivedContact
    func parse(_ vcardString: String) -> ReceivedContact? {
        let contact = ReceivedContact()

        // Normalize line endings and unfold lines (vCard spec allows folding)
        let normalizedString = vcardString
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n ", with: "") // Unfold
            .replacingOccurrences(of: "\n\t", with: "") // Unfold

        let lines = normalizedString.components(separatedBy: "\n")

        var customFields: [CustomField] = []

        for line in lines {
            // Skip empty lines
            guard !line.isEmpty else { continue }

            // Parse property:value or property;params:value
            guard let colonIndex = line.firstIndex(of: ":") else { continue }

            let propertyPart = String(line[..<colonIndex])
            let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)

            // Split property from parameters
            let propertyComponents = propertyPart.split(separator: ";", maxSplits: 1)
            let property = String(propertyComponents[0]).uppercased()
            let params = propertyComponents.count > 1 ? String(propertyComponents[1]).uppercased() : ""

            switch property {
            case "N":
                // N:LastName;FirstName;MiddleName;Prefix;Suffix
                let nameParts = value.split(separator: ";", omittingEmptySubsequences: false)
                if nameParts.count >= 1 {
                    contact.lastName = String(nameParts[0])
                }
                if nameParts.count >= 2 {
                    contact.firstName = String(nameParts[1])
                }

            case "FN":
                // Full name - only use if N wasn't provided
                if contact.firstName.isEmpty && contact.lastName.isEmpty {
                    let names = value.split(separator: " ", maxSplits: 1)
                    if names.count >= 2 {
                        contact.firstName = String(names[0])
                        contact.lastName = String(names[1])
                    } else {
                        contact.firstName = value
                    }
                }

            case "ORG":
                contact.company = value.replacingOccurrences(of: ";", with: " ")

            case "TITLE":
                contact.title = value

            case "TEL":
                if contact.phone == nil {
                    contact.phone = value
                } else {
                    // Additional phone - add as custom field
                    let label = extractLabel(from: params) ?? "Phone"
                    customFields.append(CustomField(label: label, value: value, type: .phone))
                }

            case "EMAIL":
                if contact.email == nil {
                    contact.email = value
                } else {
                    // Additional email
                    let label = extractLabel(from: params) ?? "Email"
                    customFields.append(CustomField(label: label, value: value, type: .email))
                }

            case "URL":
                if contact.website == nil {
                    contact.website = value
                } else {
                    let label = extractLabel(from: params) ?? "Website"
                    customFields.append(CustomField(label: label, value: value, type: .url))
                }

            case "NOTE":
                contact.notes = value

            case "PHOTO":
                // Handle base64 encoded photo
                if params.contains("ENCODING=B") || params.contains("ENCODING=BASE64") {
                    if let photoData = Data(base64Encoded: value, options: .ignoreUnknownCharacters) {
                        contact.photoData = photoData
                    }
                }

            case "X-PHONETIC-FIRST-NAME":
                contact.localizedFirstName = value

            case "X-PHONETIC-LAST-NAME":
                contact.localizedLastName = value

            case "X-SOCIALPROFILE":
                let label = extractLabel(from: params) ?? "Social"
                customFields.append(CustomField(label: label.capitalized, value: value, type: .social))

            case let p where p.starts(with: "X-"):
                // Custom X- fields
                let fieldName = String(p.dropFirst(2)).replacingOccurrences(of: "-", with: " ").capitalized
                customFields.append(CustomField(label: fieldName, value: value, type: .text))

            default:
                break
            }
        }

        // Set custom fields
        if !customFields.isEmpty {
            contact.customFields = customFields
        }

        // Only return if we have useful data
        guard !contact.firstName.isEmpty || !contact.lastName.isEmpty ||
              contact.localizedFirstName != nil || contact.localizedLastName != nil ||
              contact.email != nil || contact.phone != nil else {
            return nil
        }

        return contact
    }

    /// Extract TYPE label from vCard parameters
    private func extractLabel(from params: String) -> String? {
        // Look for TYPE=xxx pattern
        let components = params.split(separator: ";")
        for component in components {
            if component.starts(with: "TYPE=") {
                let typeValue = String(component.dropFirst(5))
                // Clean up common type values
                switch typeValue.uppercased() {
                case "WORK": return "Work"
                case "HOME": return "Home"
                case "CELL", "MOBILE": return "Mobile"
                case "FAX": return "Fax"
                case "PREF": return nil // Skip preference indicator
                default: return typeValue.capitalized
                }
            }
        }
        return nil
    }

    /// Parse multiple vCards from a single file (some files contain multiple contacts)
    func parseMultiple(_ vcardString: String) -> [ReceivedContact] {
        var contacts: [ReceivedContact] = []

        // Split by BEGIN:VCARD
        let vcardBlocks = vcardString.components(separatedBy: "BEGIN:VCARD")

        for block in vcardBlocks {
            guard !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let fullVcard = "BEGIN:VCARD" + block
            if let contact = parse(fullVcard) {
                contacts.append(contact)
            }
        }

        return contacts
    }
}
