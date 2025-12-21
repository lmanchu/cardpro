import WidgetKit
import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - Shared Data

/// Shared card data between app and widget
struct SharedCardData: Codable {
    let name: String
    let localizedName: String?
    let title: String?
    let company: String?
    let vcardString: String

    static let userDefaultsKey = "SharedCardData"
    static let suiteName = "group.com.lman.cardpro"

    /// Load from shared UserDefaults
    static func load() -> SharedCardData? {
        // Try App Groups first (requires paid account)
        if let sharedDefaults = UserDefaults(suiteName: suiteName),
           let data = sharedDefaults.data(forKey: userDefaultsKey) {
            return try? JSONDecoder().decode(SharedCardData.self, from: data)
        }
        // Fallback to standard UserDefaults (for development)
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey) {
            return try? JSONDecoder().decode(SharedCardData.self, from: data)
        }
        return nil
    }

    /// Save to shared UserDefaults
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        // Try App Groups first
        if let sharedDefaults = UserDefaults(suiteName: Self.suiteName) {
            sharedDefaults.set(data, forKey: Self.userDefaultsKey)
        }
        // Also save to standard (for development)
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }
}

// MARK: - Timeline Provider

struct CardProvider: TimelineProvider {
    func placeholder(in context: Context) -> CardEntry {
        CardEntry(date: Date(), cardData: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CardEntry) -> Void) {
        let entry = CardEntry(date: Date(), cardData: SharedCardData.load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CardEntry>) -> Void) {
        let entry = CardEntry(date: Date(), cardData: SharedCardData.load())
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Timeline Entry

struct CardEntry: TimelineEntry {
    let date: Date
    let cardData: SharedCardData?
}

// MARK: - QR Code Generator (Widget-local)

struct WidgetQRCodeGenerator {
    private static let context = CIContext()

    static func generateQRCode(from string: String, size: CGFloat) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Widget Views

struct CardProWidgetEntryView: View {
    var entry: CardProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Lock Screen Widgets

struct CircularWidgetView: View {
    let entry: CardEntry

    var body: some View {
        if let cardData = entry.cardData,
           let qrImage = WidgetQRCodeGenerator.generateQRCode(from: cardData.vcardString, size: 100) {
            ZStack {
                AccessoryWidgetBackground()
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "qrcode")
                    .font(.title)
            }
        }
    }
}

struct RectangularWidgetView: View {
    let entry: CardEntry

    var body: some View {
        if let cardData = entry.cardData,
           let qrImage = WidgetQRCodeGenerator.generateQRCode(from: cardData.vcardString, size: 100) {
            HStack(spacing: 8) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cardData.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let company = cardData.company {
                        Text(company)
                            .font(.caption)
                            .lineLimit(1)
                    }

                    Text("Scan QR")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.title)

                VStack(alignment: .leading) {
                    Text("CardPro")
                        .font(.headline)
                    Text("Tap to set up")
                        .font(.caption)
                }

                Spacer()
            }
        }
    }
}

struct InlineWidgetView: View {
    let entry: CardEntry

    var body: some View {
        if let cardData = entry.cardData {
            Label(cardData.name, systemImage: "qrcode")
        } else {
            Label("CardPro", systemImage: "qrcode")
        }
    }
}

struct SmallWidgetView: View {
    let entry: CardEntry

    var body: some View {
        if let cardData = entry.cardData,
           let qrImage = WidgetQRCodeGenerator.generateQRCode(from: cardData.vcardString, size: 200) {
            VStack(spacing: 4) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()

                Text(cardData.name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(8)
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "qrcode")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)

                Text("Tap to set up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

struct MediumWidgetView: View {
    let entry: CardEntry

    var body: some View {
        if let cardData = entry.cardData,
           let qrImage = WidgetQRCodeGenerator.generateQRCode(from: cardData.vcardString, size: 200) {
            HStack(spacing: 16) {
                // QR Code
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(cardData.name)
                        .font(.headline)
                        .lineLimit(1)

                    if let localizedName = cardData.localizedName {
                        Text(localizedName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let title = cardData.title {
                        Text(title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let company = cardData.company {
                        Text(company)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("Scan to add contact")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        } else {
            HStack(spacing: 16) {
                Image(systemName: "qrcode")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("CardPro")
                        .font(.headline)

                    Text("Tap to create your card")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

// MARK: - Widget Configuration

@main
struct CardProWidget: Widget {
    let kind: String = "CardProWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CardProvider()) { entry in
            CardProWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("My Card QR")
        .description("Quick access to your business card QR code")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    CardProWidget()
} timeline: {
    CardEntry(date: Date(), cardData: SharedCardData(
        name: "Leo Man",
        localizedName: "林辰陽",
        title: "CEO",
        company: "IrisGo",
        vcardString: "BEGIN:VCARD\nVERSION:3.0\nFN:Leo Man\nEND:VCARD"
    ))
    CardEntry(date: Date(), cardData: nil)
}

#Preview("Medium", as: .systemMedium) {
    CardProWidget()
} timeline: {
    CardEntry(date: Date(), cardData: SharedCardData(
        name: "Leo Man",
        localizedName: "林辰陽",
        title: "CEO",
        company: "IrisGo",
        vcardString: "BEGIN:VCARD\nVERSION:3.0\nFN:Leo Man\nEND:VCARD"
    ))
}

#Preview("Lock Screen Circular", as: .accessoryCircular) {
    CardProWidget()
} timeline: {
    CardEntry(date: Date(), cardData: SharedCardData(
        name: "Leo Man",
        localizedName: "林辰陽",
        title: "CEO",
        company: "IrisGo",
        vcardString: "BEGIN:VCARD\nVERSION:3.0\nFN:Leo Man\nEND:VCARD"
    ))
}

#Preview("Lock Screen Rectangular", as: .accessoryRectangular) {
    CardProWidget()
} timeline: {
    CardEntry(date: Date(), cardData: SharedCardData(
        name: "Leo Man",
        localizedName: "林辰陽",
        title: "CEO",
        company: "IrisGo",
        vcardString: "BEGIN:VCARD\nVERSION:3.0\nFN:Leo Man\nEND:VCARD"
    ))
}

#Preview("Lock Screen Inline", as: .accessoryInline) {
    CardProWidget()
} timeline: {
    CardEntry(date: Date(), cardData: SharedCardData(
        name: "Leo Man",
        localizedName: nil,
        title: nil,
        company: nil,
        vcardString: ""
    ))
}
