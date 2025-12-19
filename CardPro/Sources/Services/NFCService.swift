import CoreNFC
import Foundation

/// Service for NFC reading and writing
class NFCService: NSObject, ObservableObject {
    static let shared = NFCService()

    @Published var isNFCAvailable: Bool = false
    @Published var lastError: String?

    private var session: NFCNDEFReaderSession?
    private var writeMessage: NFCNDEFMessage?
    private var onReadCompletion: ((Result<String, Error>) -> Void)?

    override init() {
        super.init()
        isNFCAvailable = NFCNDEFReaderSession.readingAvailable
    }

    /// Write vCard to NFC tag
    func writeVCard(_ vcardString: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard isNFCAvailable else {
            completion(.failure(NFCError.notAvailable))
            return
        }

        // Create NDEF payload with vCard
        guard let vcardData = vcardString.data(using: .utf8) else {
            completion(.failure(NFCError.invalidData))
            return
        }

        let payload = NFCNDEFPayload(
            format: .media,
            type: "text/vcard".data(using: .utf8)!,
            identifier: Data(),
            payload: vcardData
        )

        writeMessage = NFCNDEFMessage(records: [payload])

        session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        session?.alertMessage = "Hold your iPhone near an NFC tag to write your card"
        session?.begin()
    }

    /// Read vCard from NFC tag
    func readVCard(completion: @escaping (Result<String, Error>) -> Void) {
        guard isNFCAvailable else {
            completion(.failure(NFCError.notAvailable))
            return
        }

        onReadCompletion = completion

        session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: true
        )
        session?.alertMessage = "Hold your iPhone near an NFC tag to read a card"
        session?.begin()
    }
}

extension NFCService: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Handle read
        for message in messages {
            for record in message.records {
                if let typeString = String(data: record.type, encoding: .utf8),
                   typeString == "text/vcard",
                   let vcardString = String(data: record.payload, encoding: .utf8) {
                    DispatchQueue.main.async {
                        self.onReadCompletion?(.success(vcardString))
                        self.onReadCompletion = nil
                    }
                    return
                }
            }
        }

        DispatchQueue.main.async {
            self.onReadCompletion?(.failure(NFCError.noVCardFound))
            self.onReadCompletion = nil
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found")
            return
        }

        session.connect(to: tag) { error in
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }

            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    session.invalidate(errorMessage: "Query failed: \(error.localizedDescription)")
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compatible")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is read-only")
                case .readWrite:
                    if let message = self.writeMessage {
                        tag.writeNDEF(message) { error in
                            if let error = error {
                                session.invalidate(errorMessage: "Write failed: \(error.localizedDescription)")
                            } else {
                                session.alertMessage = "Card written successfully!"
                                session.invalidate()
                            }
                        }
                    }
                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status")
                }
            }
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            if let nfcError = error as? NFCReaderError,
               nfcError.code != .readerSessionInvalidationErrorUserCanceled {
                self.lastError = error.localizedDescription
            }
        }
    }

    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        // Session is active
    }
}

enum NFCError: LocalizedError {
    case notAvailable
    case invalidData
    case noVCardFound
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "NFC is not available on this device"
        case .invalidData:
            return "Invalid card data"
        case .noVCardFound:
            return "No business card found on this tag"
        case .writeFailed:
            return "Failed to write to NFC tag"
        }
    }
}
