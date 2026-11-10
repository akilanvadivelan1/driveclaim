import SwiftUI
import UIKit

/// Dark, simple look: deep navy-purple surfaces, violet accent, pink highlights.
enum Theme {
    static let background = Color(red: 0.12, green: 0.10, blue: 0.21)   // #1F1A36
    static let card       = Color(red: 0.17, green: 0.15, blue: 0.27)   // #2B2745
    static let cardLight  = Color(red: 0.22, green: 0.19, blue: 0.34)
    static let accent     = Color(red: 0.48, green: 0.36, blue: 1.00)   // violet
    static let pink       = Color(red: 0.96, green: 0.56, blue: 0.69)
    static let textDim    = Color.white.opacity(0.55)

    static let gradient = LinearGradient(
        colors: [accent, pink], startPoint: .topLeading, endPoint: .bottomTrailing)

    // Map overlay colors (UIKit). Yours is violet, friends get their own color.
    static let mineUI = UIColor(red: 0.48, green: 0.36, blue: 1.00, alpha: 1)
    static let friendPaletteUI: [UIColor] = [
        UIColor(red: 0.96, green: 0.56, blue: 0.69, alpha: 1),   // pink
        UIColor(red: 0.30, green: 0.80, blue: 0.78, alpha: 1),   // teal
        UIColor(red: 0.98, green: 0.74, blue: 0.35, alpha: 1),   // amber
        UIColor(red: 0.45, green: 0.72, blue: 0.98, alpha: 1)    // sky
    ]
    static let otherUI = UIColor(white: 0.75, alpha: 1)           // everyone else
}

/// Rounded dark card used across screens.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// Big pill button in the violet accent.
struct PillButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.heavy))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 64)   // big target, easy to hit
            .background(color, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Small key that explains the map colors.
struct LegendView: View {
    var filter: MapFilter

    var body: some View {
        HStack(spacing: 14) {
            dot(Color(Theme.mineUI), "You")
            dot(Color(Theme.friendPaletteUI[0]), "Friends")
            if filter == .everyone { dot(Color(Theme.otherUI), "Everyone else") }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.card.opacity(0.92), in: Capsule())
    }

    private func dot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color.opacity(0.9)).frame(width: 9, height: 9)
            Text(label)
        }
    }
}
