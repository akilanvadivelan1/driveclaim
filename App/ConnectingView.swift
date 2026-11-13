import SwiftUI

/// Shown while the app finds out who is signed in. If that takes too long, it says so
/// and offers a retry, so the screen is never just blank.
struct ConnectingView: View {
    @EnvironmentObject var firebase: FirebaseService
    @State private var waitedTooLong = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                LogoView()

                if waitedTooLong {
                    VStack(spacing: 14) {
                        Text("Still trying to reach sign-in. Check your internet connection.")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.textDim)
                            .multilineTextAlignment(.center)
                        Button("Try again") {
                            waitedTooLong = false
                            firebase.restartAuthListener()
                        }
                        .buttonStyle(SmallButtonStyle(kind: .primary))
                    }
                } else {
                    VStack(spacing: 10) {
                        ProgressView().tint(Theme.text)
                        Text("Connecting")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textMuted)
                    }
                }
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
        // Restarts whenever "Try again" is tapped.
        .task(id: waitedTooLong) {
            guard !waitedTooLong else { return }
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            waitedTooLong = true
        }
    }
}
