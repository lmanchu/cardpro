# CardPro - 名片交換王

> Exchange cards like a pro

A modern iOS app for digital business card exchange with NFC, AirDrop, and QR Code support.

## Features

### ✅ Implemented

- **Business Card Editor** - Create beautiful digital cards with name, company, title, contact info, and photo
- **Card Image Design** - Three ways to create your card design:
  - 📷 Scan physical business card
  - 🖼️ Upload from photo library
  - ✨ Generate from 5 beautiful templates (Modern, Classic, Minimal, Bold, Elegant)
- **OCR Recognition** - Automatically extract contact info from scanned cards
  - Supports English, Chinese (Simplified/Traditional), Japanese
  - Smart parsing for names, phone, email, website, company, title
- **Sharing** - Share both card image (JPG) + contact file (.vcf) together
- **QR Code** - Generate scannable QR codes for easy sharing
- **NFC Support** - Write and read business cards via NFC tags
  - Write your card to NDEF NFC tags (NTAG215/216 recommended)
  - Read business cards from NFC tags
- **AirDrop Receiving** - Accept shared business cards via AirDrop
  - Supports both .vcf contact files and card images
  - Automatically combines image + contact when both are shared
- **Contacts Import** - One-tap import received cards to iOS Contacts
- **Widget** - Home screen widget showing your default card
- **Apple Wallet** - Generate wallet passes for your cards
- **Tags & Organization** - Organize received cards with custom tags
- **Beautiful UI** - Tab-based interface with card preview and quick actions

### 🔄 Coming Soon

- iCloud sync (infrastructure ready, needs testing)
- Subscription features (StoreKit 2)

## Tech Stack

- **SwiftUI** - Modern declarative UI
- **SwiftData** - Local persistence
- **Vision Framework** - OCR text recognition
- **Core NFC** - NFC support
- **Contacts Framework** - iOS contacts integration
- **PhotosUI** - Photo picker

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open `CardPro.xcodeproj` in Xcode
3. Build and run on simulator or device

## Screenshots

*Coming soon*

## License

MIT License

---

Made with ❤️ by Lman
