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

    /// State code is derived server-side from your land; shown here for context.
    @State private var myState: String = "US"

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Scope", selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if loading {
                    ProgressView("Loading...").frame(maxHeight: .infinity)
                } else if let error {
                    ContentUnavailableView("Could not load", systemImage: "wifi.slash", description: Text(error))
                } else if rows.isEmpty {
                    ContentUnavailableView("No claims yet", systemImage: "map", description: Text("Be the first to claim land here."))
                } else {
                    List(rows) { row in
                        HStack {
                            Text("#\(row.rank)").font(.headline).frame(width: 44, alignment: .leading)
                            Text(row.isMe ? "You" : shortId(row.ownerId))
                                .fontWeight(row.isMe ? .bold : .regular)
                            if let st = row.state, scope == .national { Text(st).font(.caption).foregroundColor(.secondary) }
                            Spacer()
                            Text(String(format: "%.2f sq mi", row.squareMiles)).monospacedDigit()
                        }
                        .listRowBackground(row.isMe ? Color.green.opacity(0.15) : nil)
                    }
                }
            }
            .navigationTitle(scope == .state ? "\(myState) Leaderboard" : "National Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task(id: scope) { await load() }
        }
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

    // Anonymous ids are long; show a short, stable handle.
    private func shortId(_ id: String) -> String { "Driver " + String(id.suffix(4)).uppercased() }
}
