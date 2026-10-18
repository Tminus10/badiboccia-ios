import SwiftUI

/// The Sports-app-like look: a deep blue gradient behind translucent dark cards.
enum Theme {
    static let backgroundTop = Color(red: 0.17, green: 0.24, blue: 0.62)
    static let backgroundBottom = Color(red: 0.03, green: 0.07, blue: 0.24)
    static let card = Color(red: 0.03, green: 0.07, blue: 0.27).opacity(0.62)
    static let cardHeader = Color.white.opacity(0.04)
    static let separator = Color.white.opacity(0.09)
    static let secondaryText = Color.white.opacity(0.58)
    static let tertiaryText = Color.white.opacity(0.38)
    /// Marks teams that qualify for the knockout phase.
    static let qualifier = Color(red: 1.0, green: 0.85, blue: 0.4)
    static let cornerRadius: CGFloat = 22
}

struct ThemeBackground: View {
    var body: some View {
        LinearGradient(colors: [Theme.backgroundTop, Theme.backgroundBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

extension View {
    /// The rounded dark card the Sports app puts every section in.
    func card(cornerRadius: CGFloat = Theme.cornerRadius) -> some View {
        background(Theme.card, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            }
    }

    /// Gradient background behind a scrolling screen, with a transparent navigation bar.
    func themedScreen() -> some View {
        background(ThemeBackground())
            .scrollContentBackground(.hidden)
            .toolbarBackground(.hidden, for: .navigationBar)
    }
}

extension Color {
    /// "#96e48b" -> Color; falls back to gray for anything unparsable.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            self = .gray
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// Small uppercase section heading used inside cards ("Gruppe A", "PKT").
struct CardHeading: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.secondaryText)
    }
}

/// Centered placeholder for "nothing here yet".
struct EmptyStateText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal)
    }
}
