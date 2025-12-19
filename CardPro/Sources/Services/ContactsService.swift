import Contacts
import Foundation

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

    /// Import a ReceivedContact to iOS Contacts
    func importContact(_ contact: ReceivedContact) async throws {
        // Check authorization
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw ContactsError.notAuthorized
            }
        }

        // Create CNMutableContact
        let cnContact = CNMutableContact()

        // Name
        cnContact.givenName = contact.firstName
        cnContact.familyName = contact.lastName

        // Company and title
        if let company = contact.company {
            cnContact.organizationName = company
        }
        if let title = contact.title {
            cnContact.jobTitle = title
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

        // Notes
        if let notes = contact.notes {
            cnContact.note = notes
        }

        // Save to contacts
        let saveRequest = CNSaveRequest()
        saveRequest.add(cnContact, toContainerWithIdentifier: nil)

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
