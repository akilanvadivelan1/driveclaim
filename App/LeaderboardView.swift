import SwiftUI
import TerritoryCore

/// Two sections: Friends and Nation. Each can be shown as a ranked list
/// or as a map you can zoom and drag around.
struct LeaderboardView: View {
    @EnvironmentObject var firebase: FirebaseService
    @Environment(\.dismiss) private var dismiss

    enum Board: String, CaseIterable { case friends = "Friends", nation = "Nation" }
    enum ViewMode: String, CaseIterable { case list = "List", map = "Map" }
    enum NationArea: String, CaseIterable { case all = "All U.S.", state = "My state" }

    @State private var section: Board = .friends
    @State private var layout: ViewMode = .list
    @State private var nationArea: NationArea = .all
    @State private var rows: [FirebaseService.LeaderboardRow] = []
    @State private var loading = false
    @State private var error: String?
    @State private var showFriends = false

    private var mapFilter: MapFilter { section == .friends ? .mineAndFriends : .everyone }

    private var myState: String? {
        guard let s = firebase.profile.homeState, s != "US" else { return nil }
        return s
    }

    /// Changes whenever the list needs to be fetched again.
    private var loadKey: String { "\(section.rawValue)-\(nationArea.rawValue)" }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                Picker("Section", selection: $section) {
                    ForEach(Board.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    Picker("Layout", selection: $layout) {
                        ForEach(ViewMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    if section == .nation && layout == .list && myState != nil {
                        Picker("Area", selection: $nationArea) {
                            ForEach(NationArea.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                content
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .task(id: loadKey) { await load() }
        .sheet(isPresented: $showFriends) { FriendsView() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack {
            Text(section == .friends ? "Friends" : "Nation")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
            Spacer()
            if section == .friends {
                Button { showFriends = true } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                        .background(Theme.card, in: Circle())
                }
            }
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
        if layout == .map {
            mapContent
        } else if loading {
            ProgressView().tint(.white).frame(maxHeight: .infinity)
        } else if let error {
            emptyState(icon: "wifi.slash", title: "Could not load", detail: error)
        } else if section == .friends && rows.count <= 1 {
            VStack(spacing: 14) {
                if let me = rows.first { rowView(me) }
                emptyState(icon: "person.2", title: "No friends yet",
                           detail: "Send your invite link and see who covers the most land.")
                Button("Invite friends") { showFriends = true }
                    .buttonStyle(PillButtonStyle())
            }
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

    private var mapContent: some View {
        ZStack(alignment: .bottomLeading) {
            MapView(filter: mapFilter, follow: .constant(false), fitClaims: true)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            LegendView(filter: mapFilter).padding(12)
        }
        .frame(maxHeight: .infinity)
    }

    private func rowView(_ row: FirebaseService.LeaderboardRow) -> some View {
        HStack(spacing: 14) {
            Text("\(row.rank)")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(row.rank <= 3 ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.textDim))
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.isMe ? "You" : name(for: row))
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.caption2)
                    Text(Display.minutes(row.minutesDriven) + " driven")
                    if let st = row.state, section == .nation {
                        Text("· \(st)")
                    }
                }
                .font(.caption)
                .foregroundColor(Theme.textDim)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(row.points) pts")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text(String(format: "%.2f sq mi", row.squareMiles))
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
            }
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

    // MARK: Data

    @MainActor
    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            switch section {
            case .friends:
                rows = try await firebase.leaderboard(scope: .friends)
            case .nation:
                if nationArea == .state, let state = myState {
                    rows = try await firebase.leaderboard(scope: .state, state: state)
                } else {
                    rows = try await firebase.leaderboard(scope: .national)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Players who have not picked a name show a short stable handle.
    private func name(for row: FirebaseService.LeaderboardRow) -> String {
        if let n = row.displayName, !n.isEmpty { return n }
        return "Driver " + String(row.ownerId.suffix(4)).uppercased()
    }
}
