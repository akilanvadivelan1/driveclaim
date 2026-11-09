import SwiftUI

/// State and national leaderboards, ranked by total square miles held.
struct LeaderboardView: View {
    @EnvironmentObject var firebase: FirebaseService
    @Environment(\.dismiss) private var dismiss

    enum Scope: String, CaseIterable { case national = "National", state = "My State" }

    @State private var scope: Scope = .national
    @State private var rows: [FirebaseService.LeaderboardRow] = []
    @State private var loading = false
    @State private var error: String?

    /// State code is derived server-side from your land.
    @State private var myState: String = "US"

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                header

                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                content
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .task(id: scope) { await load() }
    }

    private var header: some View {
        HStack {
            Text(scope == .state ? "\(myState) Leaders" : "Leaders")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 40, height: 40)
                    .background(Theme.card, in: Circle())
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        if loading {
            ProgressView().tint(.white).frame(maxHeight: .infinity)
        } else if let error {
            emptyState(icon: "wifi.slash", title: "Could not load", detail: error)
        } else if rows.isEmpty {
            emptyState(icon: "map", title: "No claims yet", detail: "Be the first to claim land here.")
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(rows) { row in rowView(row) }
                }
            }
        }
    }

    private func rowView(_ row: FirebaseService.LeaderboardRow) -> some View {
        HStack(spacing: 14) {
            Text("\(row.rank)")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(row.rank <= 3 ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.textDim))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.isMe ? "You" : shortId(row.ownerId))
                    .font(.headline)
                if let st = row.state, scope == .national {
                    Text(st).font(.caption).foregroundColor(Theme.textDim)
                }
            }

            Spacer()

            Text(String(format: "%.2f", row.squareMiles))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
            Text("sq mi").font(.caption).foregroundColor(Theme.textDim)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(row.isMe ? Theme.cardLight : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(row.isMe ? Theme.accent : .clear, lineWidth: 1.5)
        )
    }

    // Works on iOS 16 (ContentUnavailableView needs iOS 17).
    private func emptyState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(Theme.gradient)
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundColor(Theme.textDim).multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            rows = try await firebase.leaderboard(state: scope == .state ? myState : nil)
            if scope == .national, let mine = rows.first(where: { $0.isMe })?.state { myState = mine }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // Anonymous ids are long, so show a short stable handle.
    private func shortId(_ id: String) -> String { "Driver " + String(id.suffix(4)).uppercased() }
}
