import SwiftUI

/// Shown once, right after making an account, until the email is confirmed.
/// Firebase emails a link. Tapping it confirms the address, and this screen
/// notices on its own and moves on.
struct VerifyEmailView: View {
    @EnvironmentObject var firebase: FirebaseService

    @State private var message: String?
    @State private var busy = false
    @State private var cooldown = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "envelope.badge")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.gradient)

                Text("Check your email")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))

                Text("We sent a link to \(firebase.email ?? "your email"). Tap it, then come back here. You only need to do this once.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Theme.textDim)
                    .padding(.horizontal)

                Text("Nothing there? Check your spam folder.")
                    .font(.caption)
                    .foregroundColor(Theme.textDim)

                if let message {
                    Text(message)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Theme.pink)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button("I VERIFIED MY EMAIL") { Task { await check() } }
                        .buttonStyle(PillButtonStyle())
                        .disabled(busy)

                    Button(cooldown > 0 ? "Resend in \(cooldown)s" : "Resend email") {
                        Task { await resend() }
                    }
                    .font(.headline)
                    .foregroundColor(cooldown > 0 ? Theme.textDim : .white)
                    .disabled(busy || cooldown > 0)

                    Button("Use a different account") { try? firebase.signOut() }
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(Theme.pink)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .task { await watchForVerification() }
    }

    // MARK: Actions

    /// Quietly checks every few seconds so the screen moves on as soon as the link is tapped.
    @MainActor
    private func watchForVerification() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await firebase.refreshVerification()
        }
    }

    @MainActor
    private func check() async {
        busy = true
        message = nil
        let verified = await firebase.refreshVerification()
        busy = false
        if !verified { message = "Not verified yet. Tap the link in the email first." }
    }

    @MainActor
    private func resend() async {
        busy = true
        message = nil
        do {
            try await firebase.resendVerification()
            busy = false
            message = "Sent. It can take a minute to arrive."
            cooldown = 30
            while cooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                cooldown -= 1
            }
        } catch {
            busy = false
            message = FirebaseService.authMessage(error)
        }
    }
}
