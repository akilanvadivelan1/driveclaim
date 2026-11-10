import SwiftUI

/// Create an account or sign in. Used as the first screen, and as a sheet when a
/// guest wants to upgrade to a real account.
struct AuthView: View {
    @EnvironmentObject var firebase: FirebaseService
    @Environment(\.dismiss) private var dismiss

    /// True when this is the first screen of the app. False when shown over the game.
    var isGate: Bool

    enum Mode: String, CaseIterable {
        case create = "Create account"
        case signIn = "Sign in"
    }

    @State private var mode: Mode = .create
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = FirebaseService.rememberMe
    @State private var busy = false
    @State private var message: String?
    @State private var info: String?

    private var cleanEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canSubmit: Bool {
        let emailOK = cleanEmail.contains("@") && cleanEmail.contains(".")
        let passwordOK = mode == .create ? password.count >= 8 : !password.isEmpty
        return emailOK && passwordOK && !busy
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    if !isGate { closeRow }
                    titleBlock
                    formCard
                    if isGate { guestBlock } else { sheetNote }
                }
                .padding()
                .padding(.top, isGate ? 40 : 0)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Pieces

    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Loopd")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gradient)
            Text("Drive a loop. Claim the land.")
                .font(.subheadline)
                .foregroundColor(Theme.textDim)
        }
    }

    private var formCard: some View {
        VStack(spacing: 14) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Theme.cardLight, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            SecureField(mode == .create ? "Password (8 or more characters)" : "Password", text: $password)
                .textContentType(mode == .create ? .newPassword : .password)
                .padding(14)
                .background(Theme.cardLight, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Toggle("Remember me", isOn: $rememberMe)
                .tint(Theme.accent)
                .font(.subheadline)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(Theme.pink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let info {
                Text(info)
                    .font(.footnote)
                    .foregroundColor(Theme.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(mode == .create ? "CREATE ACCOUNT" : "SIGN IN") {
                Task { await submit() }
            }
            .buttonStyle(PillButtonStyle())
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.5)

            if mode == .signIn {
                Button("Forgot password?") { Task { await resetPassword() } }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Theme.pink)
                    .disabled(busy)
            }
        }
        .card()
    }

    /// First-screen only. Lets someone try the game before making an account.
    private var guestBlock: some View {
        VStack(spacing: 8) {
            Button("Continue as guest") { Task { await guest() } }
                .font(.headline)
                .foregroundColor(.white)
                .disabled(busy)
            Text("Guest progress is only saved on this phone. Create an account anytime to keep your land and points safe.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textDim)
        }
    }

    /// Sheet only. Explains what happens to the guest's progress.
    private var sheetNote: some View {
        Text(mode == .create
             ? "Creating an account keeps everything you have earned so far, including your land, points and friends."
             : "Signing in switches this phone to that account. Progress from your current guest session stays behind.")
            .font(.caption)
            .multilineTextAlignment(.center)
            .foregroundColor(Theme.textDim)
    }

    // MARK: Actions

    @MainActor
    private func submit() async {
        busy = true
        message = nil
        info = nil
        defer { busy = false }
        FirebaseService.rememberMe = rememberMe
        do {
            switch mode {
            case .create: try await firebase.createAccount(email: cleanEmail, password: password)
            case .signIn: try await firebase.signIn(email: cleanEmail, password: password)
            }
            if !isGate { dismiss() }
        } catch {
            message = FirebaseService.authMessage(error)
        }
    }

    @MainActor
    private func guest() async {
        busy = true
        message = nil
        defer { busy = false }
        do { try await firebase.continueAsGuest() } catch { message = FirebaseService.authMessage(error) }
    }

    @MainActor
    private func resetPassword() async {
        message = nil
        info = nil
        guard cleanEmail.contains("@") else {
            message = "Type your email above first, then tap Forgot password."
            return
        }
        busy = true
        defer { busy = false }
        do {
            try await firebase.sendPasswordReset(email: cleanEmail)
            info = "If that email has an account, a reset link is on its way."
        } catch {
            message = FirebaseService.authMessage(error)
        }
    }
}
