import SwiftUI

/// Decides what to show first: a sign-in screen, or the game.
struct RootView: View {
    @EnvironmentObject var firebase: FirebaseService

    var body: some View {
        Group {
            if !firebase.isConfigured {
                // No Firebase yet, so just show the game for previewing.
                ContentView()
            } else {
                switch firebase.authState {
                case .unknown:
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        ProgressView().tint(.white)
                    }
                case .signedOut:
                    AuthView(isGate: true)
                case .guest, .signedIn:
                    ContentView()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
