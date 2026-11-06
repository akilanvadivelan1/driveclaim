import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var firebase: FirebaseService
    @State private var showLeaderboard = false

    var body: some View {
        ZStack(alignment: .bottom) {
            MapView().ignoresSafeArea()

            // Leaderboard is top-right so it is out of the way while driving.
            VStack {
                HStack {
                    Spacer()
                    Button { showLeaderboard = true } label: {
                        Image(systemName: "trophy.fill")
                            .font(.title2)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding()
                }
                Spacer()
            }

            VStack(spacing: 12) {
                if let msg = game.statusMessage {
                    Text(msg)
                        .font(.headline)
                        .padding(10)
                        .background(.green.opacity(0.9), in: Capsule())
                        .foregroundColor(.white)
                }

                HStack {
                    stat("My square miles", String(format: "%.2f", firebase.myScoreSquareMiles))
                    stat("Speed", "\(Int(game.speedMph)) mph")
                }

                if game.submitting {
                    ProgressView("Sending your drive...")
                }

                Button(action: { game.isDriving ? game.end() : game.start() }) {
                    Text(game.isDriving ? "End drive" : "Start drive")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, minHeight: 64)  // big, easy to hit
                        .background(game.isDriving ? Color.red : Color.green, in: RoundedRectangle(cornerRadius: 16))
                        .foregroundColor(.white)
                }
                .disabled(game.submitting)

                Text("Green is your land, red is rivals. Loop through red to steal it. Set up before you drive, then listen for voice updates. Never touch your phone while moving.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        }
        .sheet(isPresented: $showLeaderboard) { LeaderboardView() }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title.bold())
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
