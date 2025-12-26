# CardPro Project Memory

## App Store Status
- **App Name**: CardPro
- **Bundle ID**: com.lman.cardpro
- **Apple ID**: 6756994446
- **SKU**: cardpro-001
- **Status**: v1.0.0 Submitted for Review (2025-12-25)
- **Current Version**: 1.2.0 (Build 1) - Contacts Sync
- **Platform**: iPhone only (TARGETED_DEVICE_FAMILY: "1")

## Version History
- **1.2.0** (2025-12-26): Contacts Sync
  - Batch import all received contacts to iPhone Contacts
  - Duplicate detection - update existing instead of creating duplicates
  - Sync status tracking (cnContactIdentifier, lastSyncedAt)
  - Gravatar auto-fetch for profile photos
- **1.1.0** (2025-12-25): Multi-card management feature
  - Card labels for identity (Work, Personal, Side Business)
  - Swipeable card carousel with page indicator
  - Edit/Delete buttons in card editor
  - HD photo capture for card images (My Cards & Received Cards)
  - Avatar/profile photo for received contacts
  - Gravatar auto-fetch via email MD5 hash
  - Manual photo upload for avatars (camera/selfie/photos)
  - Delete confirmation dialog
- **1.0.0** (2025-12-25): Initial release - MVP

## TestFlight
- **Public Link**: https://testflight.apple.com/join/He96cjKv
- **Internal Testing**: Enabled
- **External Testing**: Pending Beta App Review

## Key Decisions
- CloudKit/iCloud sync disabled (SwiftData compatibility issues)
- NFC: TAG format only (NDEF removed due to SDK 26.2 restriction)
- Launch as FREE app first to test market response
- Subscription features planned for future version

## Release Process
Run from project root:
```bash
./scripts/release.sh build   # Bump build number only
./scripts/release.sh patch   # 1.0.0 → 1.0.1
./scripts/release.sh minor   # 1.0.0 → 1.1.0
./scripts/release.sh major   # 1.0.0 → 2.0.0
```

## Important Files
- `project.yml` - XcodeGen project configuration
- `scripts/release.sh` - Automated release script
- `/tmp/ExportOptions.plist` - App Store upload options
- `~/Desktop/AppStoreScreenshots/` - App Store screenshots (1284x2778, no alpha)

## Fixes Applied
1. **Settings crash**: Removed CloudKit import and iCloud status checking from SettingsView.swift
2. **NFC upload error**: Removed NDEF from entitlements, kept TAG only
3. **Screenshot alpha**: Converted PNGs to remove alpha channel

## Subscription Model

### Free Tier
- 2 My Cards (e.g., Work + Personal)
- Unlimited Received Cards
- One-way import to iPhone Contacts
- Basic card templates
- QR Code / AirDrop sharing

### Pro Tier ($2.99/month or $29.99/year)
- ♾️ Unlimited My Cards
- 🔄 Two-way Contacts Sync (CardPro ↔ iPhone Contacts)
- ☁️ iCloud Sync (cross-device)
- 🎨 Premium Templates
- 📊 Sharing Analytics
- 🔔 Card Update Notifications

### Implementation Status
| Feature | Status |
|---------|--------|
| Card limit (3 free) | ❌ Not implemented |
| StoreKit 2 integration | ❌ Not implemented |
| Two-way sync | ❌ Not implemented |
| iCloud sync | ❌ Not implemented |
| Premium templates | ❌ Not implemented |
| Analytics | ❌ Not implemented |

## Future Roadmap
- iPad support (currently iPhone only)

### v2.0 Vision
- **Card Update Subscription via ActivityPub/ATProtocol**
  - Each user gets federated identity (@user@cardpro.xyz)
  - Card updates broadcast as ActivityPub posts
  - Subscribers follow to receive updates
  - Consider Bluesky ATProtocol as simpler alternative
- Web interface for CRM features

### v3.0 Vision - Smart Glasses & Social Context
- **Smart Glasses Integration**
  - 看到疑似認識的人 → 快速查詢是誰
  - 顯示上次社交記錄、認識的 Event
  - 支援 Meta Ray-Ban, Apple Vision Pro 等

- **Social Context Engine**
  - 關聯 Email / 對話截圖到聯絡人
  - Event-based grouping（同一場活動認識的人）
  - 對方換工作/新名片時收到通知（訂閱機制）

- **LinkedIn Integration** (TBD)
  - 連結 LinkedIn profile
  - 同步職位變動
  - 共同連結人脈
  - ⚠️ 需討論 API 限制和 scraping 風險

### Data Model 擴展需求
```
ReceivedContact:
  + eventId: String?          // 認識的活動
  + eventName: String?        // 活動名稱
  + eventDate: Date?          // 活動日期
  + linkedEmails: [EmailRef]  // 關聯的 Email
  + linkedChats: [ChatRef]    // 對話截圖
  + linkedInUrl: String?      // LinkedIn profile
  + faceEmbedding: Data?      // 人臉向量 (for smart glasses)
```

---
Last updated: 2025-12-26
