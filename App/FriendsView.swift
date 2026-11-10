import SwiftUI

/// Your name, your invite link, adding a friend by code, and your friends list.
struct FriendsView: View {
    @EnvironmentObject var firebase: FirebaseService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var nameMessage: String?
    @State private var inviteCode: String?
    @State private var codeInput = ""
    @State private var addMessage: String?
    @State private var friends: [FirebaseService.LeaderboardRow] = []
    @State private var busy = false

    private var shareText: String {
        guard let code = inviteCode else { return "" }
        return "Join me on DriveClaim and let's see who can claim the most land. "
            + "Open this link: \(FirebaseService.inviteLink(code: code)) "
            + "or type the code \(code) under Friends in the app."
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
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
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text("Friends")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
            }
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
                    .background(Theme.cardLight, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button("Save") { Task { await saveName() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(busy || name.trimmingCharacters(in: .whitespaces).count < 2)
            }
            if let nameMessage { Text(nameMessage).font(.caption).foregroundColor(Theme.pink) }
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
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Theme.accent, in: Capsule())
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                .background(Theme.cardLight, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .background(Theme.cardLight, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button("Add") { Task { await addFriend() } }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(busy || codeInput.trimmingCharacters(in: .whitespaces).count < 6)
            }
            if let addMessage { Text(addMessage).font(.caption).foregroundColor(Theme.pink) }
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
