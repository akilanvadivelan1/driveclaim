import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import TerritoryCore

/// Owns talk-to-server: anonymous sign-in, submitting a finished drive, and a
/// live listener so you see everyone's land (and losses) in real time.
final class FirebaseService: ObservableObject {
    @Published var allClaims: [RemoteClaim] = []
    @Published var myScoreSquareMiles: Double = 0
    @Published var uid: String?

    private lazy var functions = Functions.functions()
    private let db = Firestore.firestore()
    private var claimsListener: ListenerRegistration?
    private var scoreListener: ListenerRegistration?

    struct RemoteClaim: Identifiable {
        let id: String
        let ownerId: String
        let ring: [Coord]
        let squareMiles: Double
    }

    struct LeaderboardRow: Identifiable {
        let rank: Int
        let ownerId: String
        let squareMiles: Double
        let state: String?
        var id: String { "\(state ?? "US")-\(ownerId)" }
        var isMe: Bool = false
    }

    /// Anonymous auth is enough to get a stable player id without a login screen.
    func signInIfNeeded() {
        if let user = Auth.auth().currentUser { uid = user.uid; startListening(); return }
        Auth.auth().signInAnonymously { [weak self] result, _ in
            self?.uid = result?.user.uid
            self?.startListening()
        }
    }

    private func startListening() {
        claimsListener = db.collection("claims").addSnapshotListener { [weak self] snap, _ in
            guard let docs = snap?.documents else { return }
            self?.allClaims = docs.compactMap { doc in
                let d = doc.data()
                guard let owner = d["ownerId"] as? String,
                      let miles = d["squareMiles"] as? Double,
                      let geo = d["geometry"] as? [[[Double]]],
                      let outer = geo.first else { return nil }
                let ring = outer.map { Coord(lat: $0[1], lon: $0[0]) }
                return RemoteClaim(id: doc.documentID, ownerId: owner, ring: ring, squareMiles: miles)
            }
        }
        guard let uid else { return }
        scoreListener = db.collection("players").document(uid).addSnapshotListener { [weak self] snap, _ in
            self?.myScoreSquareMiles = (snap?.data()?["squareMiles"] as? Double) ?? 0
        }
    }

    /// Send a finished drive to the server. Returns (claimed, stolen) square miles.
    func submitDrive(_ trail: [TimedCoord]) async throws -> (claimed: Double, stolen: Double) {
        let payload: [String: Any] = [
            "trail": trail.map { ["lat": $0.coord.lat, "lon": $0.coord.lon, "t": $0.millis] }
        ]
        let res = try await functions.httpsCallable("submitDrive").call(payload)
        let data = res.data as? [String: Any] ?? [:]
        return (data["claimedSquareMiles"] as? Double ?? 0, data["stolenSquareMiles"] as? Double ?? 0)
    }

    /// Fetch a leaderboard. Pass a state code (e.g. "CA") for the state board,
    /// or nil for the national board.
    func leaderboard(state: String?) async throws -> [LeaderboardRow] {
        var payload: [String: Any] = ["scope": state == nil ? "national" : "state", "limit": 50]
        if let state { payload["state"] = state }
        let res = try await functions.httpsCallable("leaderboard").call(payload)
        let data = res.data as? [String: Any] ?? [:]
        let rows = data["rows"] as? [[String: Any]] ?? []
        return rows.map { r in
            let owner = r["ownerId"] as? String ?? "?"
            return LeaderboardRow(
                rank: r["rank"] as? Int ?? 0,
                ownerId: owner,
                squareMiles: r["squareMiles"] as? Double ?? 0,
                state: r["state"] as? String,
                isMe: owner == uid
            )
        }
    }

    deinit { claimsListener?.remove(); scoreListener?.remove() }
}

/// A GPS fix with a timestamp, so the server can run anti-cheat speed checks.
struct TimedCoord {
    let coord: Coord
    let millis: Double
}
