import SwiftUI

/// Your name, your invite link, adding a friend by code, and your friends list.
struct FriendsView: View {
    @EnvironmentObject var firebase: FirebaseService
    @EnvironmentObject var game: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var nameMessage: String?
    @State private var inviteCode: String?
    @State private var codeInput = ""
    @State private var addMessage: String?
    @State private var friends: [FirebaseService.LeaderboardRow] = []
    @State private var busy = false
    @State private var showAuth = false
    @State private var confirmSignOut = false
    @State private var accountMessage: String?
    @State private var confirmDelete = false
    @State private var deleting = false

    private var shareText: String {
        guard let code = inviteCode else { return "" }
        return "Join me on Loopd and let's see who can claim the most land. "
            + "Open this link: \(FirebaseService.inviteLink(code: code)) "
            + "or type the code \(code) under Friends in the app."
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    accountCard
                    nameCard
                    inviteCard
                    addCard
                    friendsCard
                }
                .padding()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            name = firebase.profile.displayName ?? ""
            await loadInvite()
            await loadFriends()
        }
        .onChange(of: firebase.friendIds) { _ in Task { await loadFriends() } }
        .sheet(isPresented: $showAuth) { AuthView(isGate: false) }
        .confirmationDialog("Sign out of Loopd?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                do { try firebase.signOut() } catch { accountMessage = error.localizedDescription }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Your land and points stay safe in your account. Sign back in anytime.")
        }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text("Friends")
                .font(.system(size: 30, weight: .bold))
            Spacer()
            IconButton(systemName: "xmark") { dismiss() }
        }
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Account").font(.headline)

            switch firebase.authState {
            case .signedIn:
                Text("Signed in as \(firebase.email ?? "your account"). Your land, points and friends are saved to this account.")
                    .font(.caption).foregroundColor(Theme.textDim)
                Button("Sign out") { confirmSignOut = true }
                    .buttonStyle(SmallButtonStyle(kind: .secondary))
                    .disabled(game.isDriving)
                if game.isDriving {
                    Text("End your drive before signing out.")
                        .font(.caption2).foregroundColor(Theme.textDim)
                }
            case .guest:
                Text("You are playing as a guest, so your progress is only saved on this phone. Create an account to keep it if you change phones or delete the app.")
                    .font(.caption).foregroundColor(Theme.textDim)
                Button("Create account or sign in") { showAuth = true }
                    .buttonStyle(SmallButtonStyle())
            default:
                Text("Accounts turn on once Firebase is set up.")
                    .font(.caption).foregroundColor(Theme.textDim)
            }

            if firebase.authState == .signedIn || firebase.authState == .guest {
                Button(deleting ? "Deleting" : "Delete account") { confirmDelete = true }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Theme.danger)
                    .disabled(game.isDriving || deleting)
                    .padding(.top, 4)
                    .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                        Button("Delete everything", role: .destructive) { Task { await deleteAccount() } }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This permanently deletes your account, your land, your points and your friend connections. It cannot be undone.")
                    }
            }

            if let accountMessage { Text(accountMessage).font(.caption).foregroundColor(Theme.danger) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    @MainActor
    private func deleteAccount() async {
        deleting = true
        accountMessage = nil
        defer { deleting = false }
        do {
            try await firebase.deleteAccount()
        } catch {
            accountMessage = "Could not delete your account: " + error.localizedDescription
        }
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your name").font(.headline)
            Text("This is what friends and the nation see on the leaderboard.")
                .font(.caption).foregroundColor(Theme.textDim)
            HStack {
                TextField("Pick a name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button("Save") { Task { await saveName() } }
                    .buttonStyle(SmallButtonStyle())
                    .disabled(busy || name.trimmingCharacters(in: .whitespaces).count < 2)
            }
            if let nameMessage { Text(nameMessage).font(.caption).foregroundColor(nameMessage == "Saved." ? Theme.positive : Theme.danger) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invite friends").font(.headline)
            Text("Send your link. If they already have the app, tapping it adds you as a friend.")
                .font(.caption).foregroundColor(Theme.textDim)

            if let code = inviteCode {
                HStack {
                    Text(code)
                        .font(.system(.title2, design: .monospaced).weight(.bold))
                        .tracking(2)
                    Spacer()
                    ShareLink(item: shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 40)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .foregroundColor(Theme.onAccent)
                    }
                }
                .padding(12)
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text(firebase.isConfigured ? "Getting your code..." : "Connect Firebase to get an invite code.")
                    .font(.subheadline).foregroundColor(Theme.textDim)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a friend").font(.headline)
            Text("Got a code from a friend? Type it here.")
                .font(.caption).foregroundColor(Theme.textDim)
            HStack {
                TextField("Friend's code", text: $codeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Button("Add") { Task { await addFriend() } }
                    .buttonStyle(SmallButtonStyle())
                    .disabled(busy || codeInput.trimmingCharacters(in: .whitespaces).count < 6)
            }
            if let addMessage { Text(addMessage).font(.caption).foregroundColor(addMessage.hasPrefix("You and") ? Theme.positive : Theme.danger) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var friendsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your friends (\(friends.count))").font(.headline)
            if friends.isEmpty {
                Text("No friends yet. Send your link above.")
                    .font(.subheadline).foregroundColor(Theme.textDim)
            } else {
                ForEach(friends) { f in
                    HStack {
                        Text(f.displayName ?? "Driver " + String(f.ownerId.suffix(4)).uppercased())
                        Spacer()
                        Text("\(f.points) pts").foregroundColor(Theme.textDim).monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    // MARK: Actions

    @MainActor
    private func loadInvite() async {
        guard firebase.isConfigured else { return }
        inviteCode = try? await firebase.myInviteCode()
    }

    @MainActor
    private func loadFriends() async {
        guard firebase.isConfigured else { return }
        let rows = (try? await firebase.leaderboard(scope: .friends)) ?? []
        friends = rows.filter { !$0.isMe }
    }

    @MainActor
    private func saveName() async {
        busy = true
        defer { busy = false }
        do {
            name = try await firebase.setDisplayName(name)
            nameMessage = "Saved."
        } catch {
            nameMessage = error.localizedDescription
        }
    }

    @MainActor
    private func addFriend() async {
        busy = true
        defer { busy = false }
        do {
            let friend = try await firebase.addFriend(code: codeInput)
            addMessage = "You and \(friend.displayName) are now friends."
            codeInput = ""
            await loadFriends()
        } catch {
            addMessage = error.localizedDescription
        }
    }
}
