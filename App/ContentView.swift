import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var firebase: FirebaseService
    @State private var showLeaderboard = false

    var body: some View {
        ZStack {
            MapView().ignoresSafeArea()

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
                bottomPanel
            }
            .padding(.horizontal)
        }
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLeaderboard) { LeaderboardView() }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Image(systemName: "car.fill")
                .font(.title3)
                .foregroundStyle(Theme.gradient)
                .frame(width: 44, height: 44)
                .background(Theme.card, in: Circle())

            Spacer()

            Text(game.isDriving ? "Driving" : "Ready")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.card, in: Capsule())

            Spacer()

            Button { showLeaderboard = true } label: {
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.gradient)
                    .frame(width: 44, height: 44)
                    .background(Theme.card, in: Circle())
            }
        }
        .padding(.top, 8)
    }

    // MARK: Big score

    private var scoreHeader: some View {
        VStack(spacing: 2) {
            Text("Your territory")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 20)

            Text(String(format: "%.2f", firebase.myScoreSquareMiles))
                .font(.system(size: 84, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.gradient)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("square miles")
                .font(.subheadline)
                .foregroundColor(Theme.textDim)
        }
    }

    // MARK: Bottom panel

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

            HStack(spacing: 12) {
                chip(icon: "speedometer", value: "\(Int(game.speedMph))", label: "mph")
                chip(icon: "square.on.square", value: legend, label: "map key")
            }

            if game.submitting {
                ProgressView("Sending your drive").tint(.white)
            }

            Button(game.isDriving ? "END DRIVE" : "START DRIVE") {
                game.isDriving ? game.end() : game.start()
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

    private var legend: String { "Purple mine, pink rivals" }

    private func chip(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.gradient)
            VStack(alignment: .leading, spacing: 0) {
                Text(value).font(.subheadline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.caption2).foregroundColor(Theme.textDim)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.cardLight, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
