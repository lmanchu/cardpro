import Foundation
import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import FirebaseStorage

// MARK: - Firebase Service

@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published private(set) var currentUser: User?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isInitialized = false
    @Published private(set) var error: String?

    private var _db: Firestore?
    private var _storage: Storage?

    private var db: Firestore {
        if _db == nil {
            _db = Firestore.firestore()
        }
        return _db!
    }

    private var storage: Storage {
        if _storage == nil {
            _storage = Storage.storage()
        }
        return _storage!
    }

    private init() {}

    // MARK: - Configuration

    func configure() {
        guard !isInitialized else { return }

        FirebaseApp.configure()
        isInitialized = true

        // Initialize Firestore with settings
        _db = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings()
        _db?.settings = settings

        // Initialize Storage
        _storage = Storage.storage()

        // Listen to auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }

        print("🔥 Firebase configured successfully")

        // Sign in anonymously at startup
        Task {
            do {
                try await self.signInAnonymously()
            } catch {
                print("🔥 Auto sign-in failed: \(error)")
            }
        }
    }

    // MARK: - Anonymous Authentication

    func signInAnonymously() async throws {
        let result = try await Auth.auth().signInAnonymously()
        currentUser = result.user

        // Create user document if it doesn't exist
        try await createUserDocumentIfNeeded()

        print("🔥 Signed in anonymously: \(result.user.uid)")
    }

    func ensureAuthenticated() async throws {
        if currentUser == nil {
            try await signInAnonymously()
        }
    }

    // MARK: - User Document

    private func createUserDocumentIfNeeded() async throws {
        guard let userId = currentUser?.uid else { return }

        let userRef = db.collection("users").document(userId)
        let snapshot = try await userRef.getDocument()

        if !snapshot.exists {
            try await userRef.setData([
                "createdAt": FieldValue.serverTimestamp(),
                "fcmTokens": [],
                "settings": [
                    "notificationsEnabled": true
                ]
            ])
        }
    }

    // MARK: - FCM Token Management

    func updateFCMToken(_ token: String) async throws {
        guard let userId = currentUser?.uid else {
            print("⚠️ Cannot update FCM token: not authenticated")
            return
        }

        try await db.collection("users").document(userId).updateData([
            "fcmTokens": FieldValue.arrayUnion([token])
        ])

        print("🔥 Updated FCM token for user \(userId)")
    }

    func removeFCMToken(_ token: String) async throws {
        guard let userId = currentUser?.uid else { return }

        try await db.collection("users").document(userId).updateData([
            "fcmTokens": FieldValue.arrayRemove([token])
        ])
    }

    // MARK: - Firestore Access

    var firestore: Firestore {
        db
    }

    var userId: String? {
        currentUser?.uid
    }

    // MARK: - Storage Access

    func uploadImage(_ data: Data, path: String) async throws -> URL {
        let ref = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()

        return url
    }

    func deleteImage(path: String) async throws {
        let ref = storage.reference().child(path)
        try await ref.delete()
    }

    // MARK: - Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        guard let user = currentUser else { return }

        // Delete user document
        try await db.collection("users").document(user.uid).delete()

        // Delete published cards
        let cards = try await db.collection("publishedCards")
            .whereField("ownerId", isEqualTo: user.uid)
            .getDocuments()

        for card in cards.documents {
            try await card.reference.delete()
        }

        // Delete subscriptions
        let subscriptions = try await db.collection("subscriptions")
            .whereField("subscriberId", isEqualTo: user.uid)
            .getDocuments()

        for sub in subscriptions.documents {
            try await sub.reference.delete()
        }

        // Delete Firebase Auth account
        try await user.delete()

        currentUser = nil
        isAuthenticated = false
    }
}

// MARK: - Firebase Card Model (for Firestore)

struct FirebaseCard: Codable, Identifiable {
    @DocumentID var id: String?
    var ownerId: String
    var version: Int
    var firstName: String
    var lastName: String
    var localizedFirstName: String?
    var localizedLastName: String?
    var company: String?
    var localizedCompany: String?
    var title: String?
    var localizedTitle: String?
    var phone: String?
    var email: String?
    var website: String?
    var photoUrl: String?
    var customFields: [FirebaseCustomField]
    var isPublic: Bool
    var publishedAt: Date
    var updatedAt: Date

    var displayName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown" : name
    }

    var displayNameWithLocalized: String {
        if let localFirst = localizedFirstName, let localLast = localizedLastName {
            return "\(displayName) (\(localLast)\(localFirst))"
        }
        return displayName
    }
}

struct FirebaseCustomField: Codable, Identifiable {
    var id: String
    var label: String
    var value: String
    var type: String
}

// MARK: - Firebase Subscription Model

struct FirebaseSubscription: Codable, Identifiable {
    @DocumentID var id: String?
    var subscriberId: String
    var cardId: String
    var cardOwnerId: String
    var subscribedAt: Date
    var lastNotifiedVersion: Int
    var lastSeenVersion: Int
    var notificationsEnabled: Bool
}
