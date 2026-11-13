import SwiftUI
import TerritoryCore

/// Shown when the player taps a piece of land on the map: whose it is and how big it is.
/// Friends are looked up by id, so the card shows the name they chose.
struct TerritoryCard: View {
    @EnvironmentObject var firebase: FirebaseService

    let selection: TerritorySelection
    var onClose: () -> Void

    @State private var info: FirebaseService.PlayerInfo?
    @State private var loading = false

    private var color: Color {
        switch selection.kind {
        case .mine:
            return Color(Theme.mineUI)
        case .friend:
            let palette = Theme.friendPaletteUI
            return Color(palette[min(max(selection.colorIndex, 0), palette.count - 1)])
        }
    }

    private var title: String {
        switch selection.kind {
        case .mine:
            return "Your land"
        case .friend:
            if let name = info?.displayName, !name.isEmpty { return name }
            if loading { return "Friend" }
            return "Driver " + String(selection.ownerId.suffix(4)).uppercased()
        }
    }

    private var subtitle: String {
        let here = String(format: "%.2f square miles here", selection.squareMiles)
        switch selection.kind {
        case .mine:
            return here
        case .friend:
            guard let info else { return here }
            return here + ", " + info.points.formatted() + " points in total"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textDim)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            IconButton(systemName: "xmark", action: onClose)
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .task(id: selection.id) { await load() }
    }

    @MainActor
    private func load() async {
        info = nil
        guard selection.kind == .friend else { return }
        loading = true
        info = await firebase.playerInfo(for: selection.ownerId)
        loading = false
    }
}
