import SwiftUI
import UIKit

/// Generates beautiful business card images from card data
class CardImageGenerator {
    static let shared = CardImageGenerator()

    private init() {}

    /// Available card templates
    enum Template: String, CaseIterable {
        case modern = "Modern"
        case classic = "Classic"
        case minimal = "Minimal"
        case bold = "Bold"
        case elegant = "Elegant"

        var primaryColor: Color {
            switch self {
            case .modern: return Color(red: 0.07, green: 0.33, blue: 0.49)  // Deep blue
            case .classic: return Color(red: 0.15, green: 0.15, blue: 0.15) // Dark gray
            case .minimal: return Color.black
            case .bold: return Color(red: 0.9, green: 0.3, blue: 0.2)       // Red-orange
            case .elegant: return Color(red: 0.6, green: 0.5, blue: 0.3)    // Gold
            }
        }

        var backgroundColor: Color {
            switch self {
            case .modern: return Color.white
            case .classic: return Color(red: 0.98, green: 0.98, blue: 0.96) // Cream
            case .minimal: return Color.white
            case .bold: return Color(red: 0.98, green: 0.98, blue: 0.98)
            case .elegant: return Color(red: 0.1, green: 0.1, blue: 0.12)   // Dark
            }
        }

        var textColor: Color {
            switch self {
            case .modern, .classic, .minimal, .bold: return Color.black
            case .elegant: return Color.white
            }
        }

        var secondaryTextColor: Color {
            switch self {
            case .modern, .classic, .minimal, .bold: return Color.gray
            case .elegant: return Color.gray
            }
        }
    }

    /// Generate card image from BusinessCard data
    @MainActor
    func generateImage(for card: BusinessCard, template: Template = .modern, size: CGSize = CGSize(width: 1050, height: 600)) -> UIImage? {
        let view = CardTemplateView(card: card, template: template)
            .frame(width: size.width, height: size.height)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0  // Retina quality

        return renderer.uiImage
    }

    /// Generate card image data
    @MainActor
    func generateImageData(for card: BusinessCard, template: Template = .modern) -> Data? {
        guard let image = generateImage(for: card, template: template) else { return nil }
        return image.jpegData(compressionQuality: 0.9)
    }
}

/// SwiftUI view for card template rendering
struct CardTemplateView: View {
    let card: BusinessCard
    let template: CardImageGenerator.Template

    var body: some View {
        ZStack {
            // Background
            template.backgroundColor

            // Content based on template
            switch template {
            case .modern:
                ModernCardLayout(card: card, template: template)
            case .classic:
                ClassicCardLayout(card: card, template: template)
            case .minimal:
                MinimalCardLayout(card: card, template: template)
            case .bold:
                BoldCardLayout(card: card, template: template)
            case .elegant:
                ElegantCardLayout(card: card, template: template)
            }
        }
    }
}

// MARK: - Card Layouts

struct ModernCardLayout: View {
    let card: BusinessCard
    let template: CardImageGenerator.Template

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            Rectangle()
                .fill(template.primaryColor)
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 16) {
                Spacer()

                // Name
                Text(card.displayName)
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(template.textColor)

                // Title & Company
                if let title = card.title {
                    Text(title)
                        .font(.system(size: 24))
                        .foregroundColor(template.secondaryTextColor)
                }
                if let company = card.company {
                    Text(company)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(template.primaryColor)
                }

                Spacer()

                // Contact info
                HStack(spacing: 32) {
                    if let phone = card.phone {
                        ContactItem(icon: "phone.fill", text: phone, color: template.primaryColor)
                    }
                    if let email = card.email {
                        ContactItem(icon: "envelope.fill", text: email, color: template.primaryColor)
                    }
                }

                if let website = card.website {
                    ContactItem(icon: "globe", text: website, color: template.primaryColor)
                }

                Spacer().frame(height: 20)
            }
            .padding(.leading, 40)
            .padding(.trailing, 20)

            Spacer()

            // Photo on right
            if let photoData = card.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
                    .padding(.trailing, 40)
            }
        }
    }
}

struct ClassicCardLayout: View {
    let card: BusinessCard
    let template: CardImageGenerator.Template

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Name centered
            Text(card.displayName)
                .font(.system(size: 38, weight: .regular, design: .serif))
                .foregroundColor(template.textColor)

            // Divider
            Rectangle()
                .fill(template.primaryColor)
                .frame(width: 60, height: 2)

            // Title & Company
            VStack(spacing: 8) {
                if let title = card.title {
                    Text(title)
                        .font(.system(size: 20, design: .serif))
                        .foregroundColor(template.secondaryTextColor)
                }
                if let company = card.company {
                    Text(company)
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .foregroundColor(template.textColor)
                }
            }

            Spacer()

            // Contact info at bottom
            HStack(spacing: 40) {
                if let phone = card.phone {
                    Text(phone)
                        .font(.system(size: 18))
                        .foregroundColor(template.secondaryTextColor)
                }
                if let email = card.email {
                    Text(email)
                        .font(.system(size: 18))
                        .foregroundColor(template.secondaryTextColor)
                }
            }

            Spacer().frame(height: 30)
        }
        .padding(40)
    }
}

struct MinimalCardLayout: View {
    let card: BusinessCard
    let template: CardImageGenerator.Template

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()

            Text(card.displayName)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(template.textColor)

            if let title = card.title, let company = card.company {
                Text("\(title) at \(company)")
                    .font(.system(size: 18))
                    .foregroundColor(template.secondaryTextColor)
            } else if let company = card.company {
                Text(company)
                    .font(.system(size: 18))
                    .foregroundColor(template.secondaryTextColor)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 6) {
                if let phone = card.phone {
                    Text(phone)
                        .font(.system(size: 16))
                        .foregroundColor(template.secondaryTextColor)
                }
                if let email = card.email {
                    Text(email)
                        .font(.system(size: 16))
                        .foregroundColor(template.secondaryTextColor)
                }
                if let website = card.website {
                    Text(website)
                        .font(.system(size: 16))
                        .foregroundColor(template.secondaryTextColor)
                }
            }

            Spacer().frame(height: 30)
        }
        .padding(50)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BoldCardLayout: View {
    let card: BusinessCard
    let template: CardImageGenerator.Template

    var body: some View {
        ZStack {
            // Accent corner
            VStack {
                HStack {
                    Spacer()
                    Triangle()
                        .fill(template.primaryColor)
                        .frame(width: 200, height: 200)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 16) {
                Spacer()

                Text(card.displayName.uppercased())
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(template.textColor)

                if let title = card.title {
                    Text(title.uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(template.primaryColor)
                }

                if let company = card.company {
                    Text(company)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(template.secondaryTextColor)
                }

                Spacer()

                HStack(spacing: 24) {
                    if let phone = card.phone {
                        Text(phone)
                            .font(.system(size: 16, weight: .medium))
                    }
                    if let email = card.email {
                        Text(email)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .foregroundColor(template.textColor)

                Spacer().frame(height: 30)
            }
            .padding(50)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ElegantCardLayout: View {
    let card: BusinessCard
    let template: CardImageGenerator.Template

    var body: some View {
        ZStack {
            // Gold accent line
            VStack {
                Spacer()
                Rectangle()
                    .fill(template.primaryColor)
                    .frame(height: 3)
                    .padding(.horizontal, 50)
                Spacer().frame(height: 80)
            }

            VStack(spacing: 20) {
                Spacer()

                Text(card.displayName)
                    .font(.system(size: 40, weight: .light, design: .serif))
                    .foregroundColor(template.textColor)
                    .tracking(4)

                if let title = card.title {
                    Text(title)
                        .font(.system(size: 18, design: .serif))
                        .foregroundColor(template.primaryColor)
                        .tracking(2)
                }

                if let company = card.company {
                    Text(company.uppercased())
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(template.secondaryTextColor)
                        .tracking(3)
                }

                Spacer()

                HStack(spacing: 30) {
                    if let phone = card.phone {
                        Text(phone)
                            .font(.system(size: 14))
                    }
                    Text("•")
                    if let email = card.email {
                        Text(email)
                            .font(.system(size: 14))
                    }
                }
                .foregroundColor(template.secondaryTextColor)

                Spacer().frame(height: 40)
            }
            .padding(40)
        }
    }
}

// MARK: - Helper Views

struct ContactItem: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("Modern") {
    CardTemplateView(
        card: BusinessCard(
            firstName: "Leo",
            lastName: "Man",
            company: "IrisGo",
            title: "Founder & CEO",
            phone: "+886 912 345 678",
            email: "leo@irisgo.xyz",
            website: "https://irisgo.xyz"
        ),
        template: .modern
    )
    .frame(width: 525, height: 300)
}

#Preview("Classic") {
    CardTemplateView(
        card: BusinessCard(
            firstName: "Leo",
            lastName: "Man",
            company: "IrisGo",
            title: "Founder & CEO",
            phone: "+886 912 345 678",
            email: "leo@irisgo.xyz"
        ),
        template: .classic
    )
    .frame(width: 525, height: 300)
}

#Preview("Elegant") {
    CardTemplateView(
        card: BusinessCard(
            firstName: "Leo",
            lastName: "Man",
            company: "IrisGo",
            title: "Founder & CEO",
            phone: "+886 912 345 678",
            email: "leo@irisgo.xyz"
        ),
        template: .elegant
    )
    .frame(width: 525, height: 300)
}
