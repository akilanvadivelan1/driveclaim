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

    // Map overlay colors (UIKit)
    static let mineUI  = UIColor(red: 0.48, green: 0.36, blue: 1.00, alpha: 1)
    static let rivalUI = UIColor(red: 0.96, green: 0.56, blue: 0.69, alpha: 1)
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
