import Contacts
import Foundation

/// Represents a contact container (account) like iCloud or Google
struct ContactContainer: Identifiable {
    let id: String
    let name: String
    let type: CNContainerType

    var displayName: String {
        switch type {
        case .local:
            return "iPhone (\(name))"
        case .exchange:
            return "Exchange (\(name))"
        case .cardDAV:
            // CardDAV includes iCloud and Google
            if name.lowercased().contains("icloud") {
                return "iCloud"
            } else if name.lowercased().contains("google") || name.lowercased().contains("gmail") {
                return "Google"
            }
            return name
        @unknown default:
            return name
        }
    }

    var iconName: String {
        switch type {
        case .local:
            return "iphone"
        case .exchange:
            return "envelope.fill"
        case .cardDAV:
            if name.lowercased().contains("icloud") {
                return "icloud.fill"
            } else if name.lowercased().contains("google") || name.lowercased().contains("gmail") {
                return "g.circle.fill"
            }
            return "person.crop.circle.fill"
        @unknown default:
            return "person.crop.circle.fill"
        }
    }
}

/// Service for importing contacts to iOS Contacts app
class ContactsService {
    static let shared = ContactsService()

    private let store = CNContactStore()

    private init() {}

    /// Request permission to access contacts
    func requestAccess() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            print("Error requesting contacts access: \(error)")
            return false
        }
    }

    /// Check current authorization status
    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Fetch all available contact containers (accounts)
    func fetchContainers() async throws -> [ContactContainer] {
        // Check authorization first
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw ContactsError.notAuthorized
            }
        }

        let containers = try store.containers(matching: nil)
        return containers.map { container in
            ContactContainer(
                id: container.identifier,
                name: container.name,
                type: container.type
            )
        }
    }

    /// Get the default container identifier
    func defaultContainerIdentifier() -> String? {
        return store.defaultContainerIdentifier()
    }

    /// Import a ReceivedContact to iOS Contacts
    func importContact(_ contact: ReceivedContact, toContainer containerId: String? = nil) async throws {
        // Check authorization
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw ContactsError.notAuthorized
            }
        }

        // Create CNMutableContact
        let cnContact = CNMutableContact()

        // Name - use Western name as primary, CJK as phonetic
        cnContact.givenName = contact.firstName
        cnContact.familyName = contact.lastName

        // Localized name (中文/日文) stored as phonetic name
        // This helps with sorting and searching in CJK locales
        if let localizedFirst = contact.localizedFirstName {
            cnContact.phoneticGivenName = localizedFirst
        }
        if let localizedLast = contact.localizedLastName {
            cnContact.phoneticFamilyName = localizedLast
        }

        // If no Western name but has CJK name, use CJK as primary
        if contact.firstName.isEmpty && contact.lastName.isEmpty {
            if let localizedFirst = contact.localizedFirstName {
                cnContact.givenName = localizedFirst
            }
            if let localizedLast = contact.localizedLastName {
                cnContact.familyName = localizedLast
            }
        }

        // Company and title (prefer Western, add localized to notes if different)
        if let company = contact.company {
            cnContact.organizationName = company
        } else if let localizedCompany = contact.localizedCompany {
            cnContact.organizationName = localizedCompany
        }

        if let title = contact.title {
            cnContact.jobTitle = title
        } else if let localizedTitle = contact.localizedTitle {
            cnContact.jobTitle = localizedTitle
        }

        // Phone
        if let phone = contact.phone {
            let phoneValue = CNLabeledValue(
                label: CNLabelPhoneNumberMobile,
                value: CNPhoneNumber(stringValue: phone)
            )
            cnContact.phoneNumbers = [phoneValue]
        }

        // Email
        if let email = contact.email {
            let emailValue = CNLabeledValue(
                label: CNLabelWork,
                value: email as NSString
            )
            cnContact.emailAddresses = [emailValue]
        }

        // Website
        if let website = contact.website {
            let urlValue = CNLabeledValue(
                label: CNLabelURLAddressHomePage,
                value: website as NSString
            )
            cnContact.urlAddresses = [urlValue]
        }

        // Photo
        if let photoData = contact.photoData {
            cnContact.imageData = photoData
        }

        // Build notes with localized info
        var noteLines: [String] = []

        // Add original notes
        if let notes = contact.notes, !notes.isEmpty {
            noteLines.append(notes)
        }

        // Add localized company/title if different from primary
        if let localizedCompany = contact.localizedCompany,
           let company = contact.company,
           localizedCompany != company {
            noteLines.append("公司: \(localizedCompany)")
        }
        if let localizedTitle = contact.localizedTitle,
           let title = contact.title,
           localizedTitle != title {
            noteLines.append("職稱: \(localizedTitle)")
        }

        // Add received info
        if let location = contact.receivedLocation {
            noteLines.append("收到地點: \(location)")
        }
        if let event = contact.receivedEvent {
            noteLines.append("活動: \(event)")
        }

        if !noteLines.isEmpty {
            cnContact.note = noteLines.joined(separator: "\n")
        }

        // Save to contacts
        let saveRequest = CNSaveRequest()
        saveRequest.add(cnContact, toContainerWithIdentifier: containerId)

        try store.execute(saveRequest)
    }

    /// Import a BusinessCard to iOS Contacts
    func importCard(_ card: BusinessCard) async throws {
        // Check authorization
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw ContactsError.notAuthorized
            }
        }

        let cnContact = CNMutableContact()

        cnContact.givenName = card.firstName
        cnContact.familyName = card.lastName

        if let company = card.company {
            cnContact.organizationName = company
        }
        if let title = card.title {
            cnContact.jobTitle = title
        }

        if let phone = card.phone {
            cnContact.phoneNumbers = [
                CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))
            ]
        }

        if let email = card.email {
            cnContact.emailAddresses = [
                CNLabeledValue(label: CNLabelWork, value: email as NSString)
            ]
        }

        if let website = card.website {
            cnContact.urlAddresses = [
                CNLabeledValue(label: CNLabelURLAddressHomePage, value: website as NSString)
            ]
        }

        if let photoData = card.photoData {
            cnContact.imageData = photoData
        }

        if let notes = card.notes {
            cnContact.note = notes
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(cnContact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)
    }
}

enum ContactsError: LocalizedError {
    case notAuthorized
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Contacts access not authorized. Please enable in Settings."
        case .saveFailed:
            return "Failed to save contact."
        }
    }
}
