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

            VStack(spacing: 0) {
                scoreboard
                Spacer()
                if game.isDriving && !follow { recenterButton }
                bottomPanel
            }
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

    // MARK: Scoreboard

    /// Points are the whole point, so they take the top of the screen.
    /// The number counts up when a claim lands, with the gain beside it.
    private var scoreboard: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Points")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textDim)

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(firebase.profile.points, format: .number)
                        .font(.system(size: 56, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.5), value: firebase.profile.points)

                    if let gain = game.lastGainPoints {
                        Text("+\(gain.formatted())")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.positive)
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.3), value: game.lastGainPoints)

                Text(String(format: "%.2f square miles", max(0, firebase.profile.squareMiles)))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textDim)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                IconButton(systemName: "person.2") { sheet = .friends }
                IconButton(systemName: "trophy") { sheet = .leaders }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background(Theme.background.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    // MARK: Bottom panel

    private var recenterButton: some View {
        HStack {
            Spacer()
            IconButton(systemName: "location") { follow = true }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var buttonTitle: String {
        if game.submitting { return "Sending drive" }
        return game.isDriving ? "End drive" : "Start drive"
    }

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if let msg = game.statusMessage { statusBar(msg) }

            statRow

            Button(buttonTitle) {
                if game.isDriving {
                    game.end()
                } else {
                    follow = true
                    game.start()
                }
            }
            .buttonStyle(game.isDriving
                         ? GameButtonStyle(fill: Theme.dangerFill, lip: Theme.dangerLip, text: .white)
                         : GameButtonStyle())
            .disabled(game.submitting)
            .opacity(game.submitting ? 0.6 : 1)

            Text("Set up before you drive. Never touch your phone while moving.")
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func statusBar(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(game.statusIsError ? Theme.danger : Theme.text)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// While driving: this drive's time and miles, updating live.
    /// Otherwise: your lifetime totals.
    private var statRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 0) {
                stat("\(Int(game.speedMph))", "mph")
                if game.isDriving, let start = game.driveStartedAt {
                    let seconds = max(0, Int(context.date.timeIntervalSince(start)))
                    stat(String(format: "%d:%02d", seconds / 60, seconds % 60), "time")
                    stat(String(format: "%.2f", game.driveMiles), "miles")
                } else {
                    stat(Display.minutes(firebase.profile.minutesDriven), "time driven")
                    stat(String(format: "%.1f", firebase.profile.milesDriven), "miles driven")
                }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Invite links

    @MainActor
    private func accept(_ invite: FirebaseService.PendingInvite) async {
        firebase.pendingInvite = nil
        do {
            let friend = try await firebase.addFriend(code: invite.code)
            game.statusIsError = false
            game.statusMessage = "You and \(friend.displayName) are now friends."
        } catch {
            game.statusIsError = true
            game.statusMessage = error.localizedDescription
        }
    }
}
