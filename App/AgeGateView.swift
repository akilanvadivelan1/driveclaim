import SwiftUI

/// Where the age answer is remembered on this phone.
enum AgeGate {
    static let confirmedKey = "age13Confirmed"
    static let blockedKey = "age13Blocked"
}

/// Asked once, before sign-in. Both answers look the same so neither one is pushed.
/// Answering "under 13" is final on this phone, so changing the answer is not an option.
struct AgeGateView: View {
    @EnvironmentObject var firebase: FirebaseService
    @AppStorage(AgeGate.confirmedKey) private var confirmed = false
    @AppStorage(AgeGate.blockedKey) private var blocked = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Text("Loopd")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(Theme.accent)

                VStack(spacing: 10) {
                    Text("Are you 13 or older?")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text("Loopd uses your location while you drive, so we need to know you are old enough to play.")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.textDim)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button("Yes, I am 13 or older") { confirmed = true }
                        .buttonStyle(equalStyle)
                    Button("No, I am under 13") { decline() }
                        .buttonStyle(equalStyle)
                }

                Spacer()
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }

    /// Both buttons share one style, so the screen does not nudge anyone toward "yes".
    private var equalStyle: GameButtonStyle {
        GameButtonStyle(fill: Theme.raised, lip: Theme.card, text: Theme.text)
    }

    private func decline() {
        blocked = true
        // Leave any account or guest session that was already on this phone.
        if firebase.isConfigured { try? firebase.signOut() }
    }
}

/// Shown for good once someone says they are under 13.
struct UnderAgeView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 12) {
                Text("Loopd is for ages 13 and up")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Theme.text)
                    .multilineTextAlignment(.center)
                Text("Thanks for being honest. We can't make an account or use your location for you right now. Come back when you turn 13.")
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .preferredColorScheme(.dark)
    }
}
