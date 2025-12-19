import SwiftUI

struct CardPreviewView: View {
    let card: BusinessCard

    var body: some View {
        VStack(spacing: 0) {
            // Card header with gradient
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 100)

                HStack(alignment: .bottom, spacing: 16) {
                    // Photo
                    if let photoData = card.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .offset(y: 40)
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.9))
                            .offset(y: 40)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }

            // Card content
            VStack(alignment: .leading, spacing: 12) {
                // Name and title
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let title = card.title, !title.isEmpty {
                        Text(title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let company = card.company, !company.isEmpty {
                        Text(company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 48)

                Divider()

                // Contact info
                VStack(alignment: .leading, spacing: 8) {
                    if let phone = card.phone, !phone.isEmpty {
                        ContactInfoRow(icon: "phone.fill", text: phone)
                    }

                    if let email = card.email, !email.isEmpty {
                        ContactInfoRow(icon: "envelope.fill", text: email)
                    }

                    if let website = card.website, !website.isEmpty {
                        ContactInfoRow(icon: "globe", text: website)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

struct ContactInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.subheadline)
        }
    }
}

#Preview {
    CardPreviewView(card: BusinessCard(
        firstName: "Leo",
        lastName: "Man",
        company: "IrisGo",
        title: "Founder & CEO",
        phone: "+886 912 345 678",
        email: "leo@irisgo.xyz",
        website: "https://irisgo.xyz"
    ))
    .padding()
}
