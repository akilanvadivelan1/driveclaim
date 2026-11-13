import SwiftUI
import UIKit

/// The Loopd logo with the name under it. Uses the logo image once it has been added
/// with scripts/add-logo.sh, and falls back to the plain name until then, so the app
/// always builds and runs.
struct LogoView: View {
    var size: CGFloat = 88

    private var mark: UIImage? { UIImage(named: "LogoMark") }

    var body: some View {
        if let mark {
            VStack(spacing: 10) {
                Image(uiImage: mark)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    // The same corner shape iOS puts on app icons.
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
                Text("Loopd")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.text)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loopd")
        } else {
            Text("Loopd")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Theme.accent)
        }
    }
}
