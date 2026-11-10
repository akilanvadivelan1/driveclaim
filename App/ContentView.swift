import SwiftUI
import TerritoryCore

struct ContentView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var firebase: FirebaseService

    enum Sheet: String, Identifiable {
        case leaders, friends
        var id: String { rawValue }
    }

    @State private var sheet: Sheet?
    @State private var follow = true
    @State private var showInviteAlert = false

    var body: some View {
        ZStack {
            MapView(follow: $follow).ignoresSafeArea()

            // Soft fade so the big number stays readable over the map.
            VStack {
                LinearGradient(colors: [Theme.background, Theme.background.opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 300)
                Spacer()
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                scoreHeader
                Spacer()
                if game.isDriving && !follow { recenterButton }
                bottomPanel
            }
            .padding(.horizontal)
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .sheet(item: $sheet) { which in
            switch which {
            case .leaders: LeaderboardView()
            case .friends: FriendsView()
            }
        }
        .onReceive(firebase.$pendingInvite) { showInviteAlert = ($0 != nil) }
        .alert("Add friend?", isPresented: $showInviteAlert, presenting: firebase.pendingInvite) { invite in
            Button("Add friend") { Task { await accept(invite) } }
            Button("Not now", role: .cancel) { firebase.pendingInvite = nil }
        } message: { _ in
            Text("Someone invited you to compete on Loopd. Add them as a friend?")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            roundButton("person.2.fill") { sheet = .friends }

            Spacer()

            Text(game.isDriving ? "Driving" : "Ready")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.card, in: Capsule())

            Spacer()

            roundButton("trophy.fill") { sheet = .leaders }
        }
        .padding(.top, 8)
    }

    private func roundButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.gradient)
                .frame(width: 44, height: 44)
                .background(Theme.card, in: Circle())
        }
    }

    // MARK: Big score

    private var scoreHeader: some View {
        VStack(spacing: 2) {
            Text("Your points")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 20)

            Text("\(firebase.profile.points)")
                .font(.system(size: 84, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gradient)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text(String(format: "%.2f square miles", max(0, firebase.profile.squareMiles)))
                .font(.subheadline)
                .foregroundColor(Theme.textDim)
        }
    }

    // MARK: Bottom panel

    private var recenterButton: some View {
        HStack {
            Spacer()
            Button { follow = true } label: {
                Image(systemName: "location.fill")
                    .font(.title3)
                    .frame(width: 48, height: 48)
                    .background(Theme.card, in: Circle())
            }
        }
        .padding(.bottom, 8)
    }

    private var bottomPanel: some View {
        VStack(spacing: 14) {
            if let msg = game.statusMessage {
                Text(msg)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.cardLight, in: Capsule())
            }

            HStack(spacing: 10) {
                chip(icon: "speedometer", value: "\(Int(game.speedMph))", label: "mph")
                chip(icon: "clock", value: Display.minutes(firebase.profile.minutesDriven), label: "driven")
                chip(icon: "road.lanes", value: String(format: "%.1f", firebase.profile.milesDriven), label: "miles")
            }

            if game.submitting {
                ProgressView("Sending your drive").tint(.white)
            }

            Button(game.isDriving ? "END DRIVE" : "START DRIVE") {
                if game.isDriving {
                    game.end()
                } else {
                    follow = true
                    game.start()
                }
            }
            .buttonStyle(PillButtonStyle(color: game.isDriving ? Theme.pink.opacity(0.9) : Theme.accent))
            .disabled(game.submitting)

            Text("Set up before you drive. Results are spoken aloud. Never touch your phone while moving.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textDim)
        }
        .card()
        .padding(.bottom, 8)
    }

    private func chip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.gradient)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.caption2).foregroundColor(Theme.textDim)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Theme.cardLight, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Invite links

    @MainActor
    private func accept(_ invite: FirebaseService.PendingInvite) async {
        firebase.pendingInvite = nil
        do {
            let friend = try await firebase.addFriend(code: invite.code)
            game.statusMessage = "You and \(friend.displayName) are now friends."
        } catch {
            game.statusMessage = error.localizedDescription
        }
    }
}
