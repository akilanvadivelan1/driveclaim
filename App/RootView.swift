import SwiftUI

/// Decides what to show first: the age question, a sign-in screen, or the game.
struct RootView: View {
    @EnvironmentObject var firebase: FirebaseService
    @AppStorage(AgeGate.confirmedKey) private var ageConfirmed = false
    @AppStorage(AgeGate.blockedKey) private var ageBlocked = false

    var body: some View {
        Group {
            if ageBlocked {
                UnderAgeView()
            } else if !ageConfirmed {
                AgeGateView()
            } else if !firebase.isConfigured {
                // No Firebase yet, so just show the game for previewing.
                ContentView()
            } else {
                switch firebase.authState {
                case .unknown:
                    ConnectingView()
                case .signedOut:
                    AuthView(isGate: true)
                case .needsVerification:
                    VerifyEmailView()
                case .guest, .signedIn:
                    ContentView()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
