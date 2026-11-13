import SwiftUI
import UIKit

/// Night asphalt, road-paint yellow. Flat colors only: no gradients, no glows.
///
/// Concept: yellow is you. Your land, your score and the start button are yellow,
/// and nobody else gets that color. Everything else is a neutral you can beat.
enum Theme {
    // Surfaces: warm graphite, like asphalt under street lights.
    static let background = Color(hex: 0x161513)
    static let card       = Color(hex: 0x1C1A18)
    static let raised     = Color(hex: 0x262421)
    static let hairline   = Color(hex: 0xEFE9DE).opacity(0.08)

    // Three text roles.
    static let text      = Color(hex: 0xEFE9DE)
    static let textDim   = Color(hex: 0xAAA398)
    static let textMuted = Color(hex: 0x8A847A)

    // Road-paint yellow, with dark text on top.
    static let accent     = Color(hex: 0xFFC72C)
    static let accentLip  = Color(hex: 0xB58A0A)   // the solid edge under the game button
    static let onAccent   = Color(hex: 0x1A1500)

    // Status colors.
    static let danger     = Color(hex: 0xF2595E)   // text on dark surfaces
    static let dangerFill = Color(hex: 0xD93A40)   // button fill, white text on top
    static let dangerLip  = Color(hex: 0x8F2226)
    static let positive   = Color(hex: 0x4CC38A)

    // Map overlays (UIKit). Yours is yellow, each friend gets a color, everyone else is grey.
    static let mineUI = UIColor(hex: 0xFFC72C)
    static let friendPaletteUI: [UIColor] = [
        UIColor(hex: 0x3DCBD9),   // cyan
        UIColor(hex: 0xFF8A4C),   // orange
        UIColor(hex: 0x6AA7FF),   // sky blue
        UIColor(hex: 0xA6E22E)    // lime
    ]
    static let otherUI = UIColor(white: 0.78, alpha: 1)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

/// A flat card with a hairline edge.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// The big game button. A solid face sits on a solid lip, and pressing it pushes the
/// face down onto the lip, like a physical arcade button.
struct GameButtonStyle: ButtonStyle {
    var fill: Color = Theme.accent
    var lip: Color = Theme.accentLip
    var text: Color = Theme.onAccent
    var height: CGFloat = 60

    let depth: CGFloat = 5
    let radius: CGFloat = 12

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(text)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .offset(y: pressed ? depth : 0)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(lip)
                    .offset(y: depth)
            )
            .padding(.bottom, depth)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

/// Smaller buttons for forms and settings.
struct SmallButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, danger }
    var kind: Kind = .primary

    private var background: Color {
        switch kind {
        case .primary: return Theme.accent
        case .secondary: return Theme.raised
        case .danger: return Theme.dangerFill
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return Theme.onAccent
        case .secondary: return Theme.text
        case .danger: return .white
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// A square icon button for the screen corners.
struct IconButton: View {
    var systemName: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Theme.text)
                .frame(width: 44, height: 44)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

/// Small key that explains the map colors.
struct LegendView: View {
    var filter: MapFilter

    var body: some View {
        HStack(spacing: 14) {
            dot(Color(Theme.mineUI), "You")
            friendsKey
            if filter == .everyone { dot(Color(Theme.otherUI), "Everyone else") }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(Theme.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Friends each get their own color, so the key shows a few of them.
    private var friendsKey: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(Color(Theme.friendPaletteUI[i])).frame(width: 9, height: 9)
                }
            }
            Text("Friends")
        }
    }

    private func dot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(label)
        }
    }
}
