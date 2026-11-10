import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import TerritoryCore

/// Talks to the server: sign-in, drives, leaderboards, friends and live land.
final class FirebaseService: ObservableObject {
    @Published var allClaims: [RemoteClaim] = []
    @Published var profile = Profile()
    @Published var friendIds: Set<String> = []
    @Published var uid: String?
    @Published var email: String?
    @Published var authState: AuthState = .unknown
    /// Set when the app is opened from an invite link, until the user answers.
    @Published var pendingInvite: PendingInvite?

    private lazy var functions = Functions.functions()
    private lazy var db = Firestore.firestore()
    private var claimsListener: ListenerRegistration?
    private var profileListener: ListenerRegistration?
    private var friendsListener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    enum AuthState: Equatable {
        case unknown      // still checking
        case signedOut    // show the sign-in screen
        case guest        // playing without an account
        case signedIn     // has an email account
    }

    /// False until GoogleService-Info.plist is added. The UI still runs without it.
    var isConfigured: Bool { FirebaseApp.app() != nil }

    struct NotConfigured: LocalizedError {
        var errorDescription: String? { "Firebase is not set up yet. Add GoogleService-Info.plist." }
    }

    // MARK: Models

    struct Profile {
        var displayName: String?
        var squareMiles: Double = 0
        var minutesDriven: Int = 0
        var milesDriven: Double = 0
        var homeState: String?
        var points: Int { Scoring.points(forSquareMiles: max(0, squareMiles)) }
    }

    struct RemoteClaim: Identifiable {
        let id: String
        let ownerId: String
        /// Polygons, each a list of rings (outer edge first, then holes).
        let polygons: [[[Coord]]]
        let squareMiles: Double
    }

    struct PendingInvite: Identifiable, Equatable {
        let code: String
        var id: String { code }
    }

    enum LeaderScope: String { case friends, national, state }

    struct LeaderboardRow: Identifiable {
        let rank: Int
        let ownerId: String
        let displayName: String?
        let squareMiles: Double
        let points: Int
        let minutesDriven: Int
        let state: String?
        var isMe: Bool
        var id: String { ownerId }
    }

    struct FriendResult {
        let friendId: String
        let displayName: String
    }

    // MARK: Sign in and live data

    // MARK: Accounts

    /// Call once when the app appears. Watches sign-in state for the whole app.
    /// The listener fires right away with whoever is already signed in (or nobody).
    func start() {
        guard isConfigured, authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            if let user {
                self.apply(user)
                self.startListening()
            } else {
                self.stopListening()
                self.uid = nil
                self.email = nil
                self.allClaims = []
                self.profile = Profile()
                self.friendIds = []
                self.authState = .signedOut
            }
        }
    }

    private func apply(_ user: User) {
        uid = user.uid
        email = user.email
        authState = user.isAnonymous ? .guest : .signedIn
    }

    /// Guests get a temporary identity so they can play right away.
    func continueAsGuest() async throws {
        guard isConfigured else { throw NotConfigured() }
        _ = try await Auth.auth().signInAnonymously()
    }

    /// Makes an account. If you are playing as a guest, the guest is upgraded in place,
    /// so your land, points and friends come with you.
    func createAccount(email: String, password: String) async throws {
        guard isConfigured else { throw NotConfigured() }
        if let user = Auth.auth().currentUser, user.isAnonymous {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            let result = try await user.link(with: credential)
            // Linking keeps the same player id and does not trigger the state listener.
            await MainActor.run { self.apply(result.user) }
        } else {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        }
    }

    /// Signs in to an existing account, for example after reinstalling or on a new phone.
    func signIn(email: String, password: String) async throws {
        guard isConfigured else { throw NotConfigured() }
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func sendPasswordReset(email: String) async throws {
        guard isConfigured else { throw NotConfigured() }
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    /// Plain-English messages. Firebase's error codes are fixed numbers, so matching on
    /// them works across SDK versions.
    static func authMessage(_ error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == "FIRAuthErrorDomain" else { return error.localizedDescription }
        switch ns.code {
        case 17007: return "That email already has an account. Try signing in instead."
        case 17008: return "That email address does not look right."
        case 17026: return "Pick a stronger password with at least 8 characters."
        case 17004, 17009, 17011: return "That email or password is not right."
        case 17010: return "Too many tries. Please wait a bit and try again."
        case 17020: return "No internet connection. Please try again."
        case 17005: return "This account has been turned off."
        case 17006: return "Email sign-in is switched off. Turn on Email/Password in the Firebase console."
        case 17025: return "That email is already linked to a different account."
        default: return error.localizedDescription
        }
    }

    private func startListening() {
        guard let uid else { return }
        stopListening()

        claimsListener = db.collection("claims").addSnapshotListener { [weak self] snap, _ in
            guard let docs = snap?.documents else { return }
            self?.allClaims = docs.compactMap { doc in
                let d = doc.data()
                guard let owner = d["ownerId"] as? String,
                      let miles = (d["squareMiles"] as? NSNumber)?.doubleValue,
                      let json = d["geometry"] as? String else { return nil }
                let polygons = GeoJSONGeometry.parsePolygons(json)
                guard !polygons.isEmpty else { return nil }
                return RemoteClaim(id: doc.documentID, ownerId: owner, polygons: polygons, squareMiles: miles)
            }
        }

        profileListener = db.collection("players").document(uid).addSnapshotListener { [weak self] snap, _ in
            let d = snap?.data() ?? [:]
            var p = Profile()
            p.displayName = d["displayName"] as? String
            p.squareMiles = (d["squareMiles"] as? NSNumber)?.doubleValue ?? 0
            p.minutesDriven = Int(((d["minutesDriven"] as? NSNumber)?.doubleValue ?? 0).rounded())
            p.milesDriven = (d["milesDriven"] as? NSNumber)?.doubleValue ?? 0
            p.homeState = d["homeState"] as? String
            self?.profile = p
        }

        friendsListener = db.collection("friendships")
            .whereField("members", arrayContains: uid)
            .addSnapshotListener { [weak self] snap, _ in
                guard let docs = snap?.documents else { return }
                var ids = Set<String>()
                for doc in docs {
                    for member in (doc.data()["members"] as? [String] ?? []) where member != uid {
                        ids.insert(member)
                    }
                }
                self?.friendIds = ids
            }
    }

    private func stopListening() {
        claimsListener?.remove()
        profileListener?.remove()
        friendsListener?.remove()
    }

    deinit {
        stopListening()
        if let handle = authHandle { Auth.auth().removeStateDidChangeListener(handle) }
    }

    // MARK: Calls to the server

    private func call(_ name: String, _ payload: [String: Any] = [:]) async throws -> [String: Any] {
        guard isConfigured else { throw NotConfigured() }
        let result = try await functions.httpsCallable(name).call(payload)
        return result.data as? [String: Any] ?? [:]
    }

    private func number(_ any: Any?) -> Double { (any as? NSNumber)?.doubleValue ?? 0 }

    struct DriveResult {
        let claimedSquareMiles: Double
        let claimedPoints: Int
        let stolenSquareMiles: Double
        let stolenPoints: Int
    }

    /// Send a finished drive to the server.
    func submitDrive(_ trail: [TimedCoord]) async throws -> DriveResult {
        let payload: [String: Any] = [
            "trail": trail.map { ["lat": $0.coord.lat, "lon": $0.coord.lon, "t": $0.millis] }
        ]
        let d = try await call("submitDrive", payload)
        return DriveResult(
            claimedSquareMiles: number(d["claimedSquareMiles"]),
            claimedPoints: Int(number(d["claimedPoints"])),
            stolenSquareMiles: number(d["stolenSquareMiles"]),
            stolenPoints: Int(number(d["stolenPoints"])))
    }

    /// Standings for friends, the whole nation, or one state.
    func leaderboard(scope: LeaderScope, state: String? = nil) async throws -> [LeaderboardRow] {
        var payload: [String: Any] = ["scope": scope.rawValue]
        if let state { payload["state"] = state }
        let d = try await call("leaderboard", payload)
        let rows = d["rows"] as? [[String: Any]] ?? []
        return rows.map { r in
            let owner = r["ownerId"] as? String ?? "?"
            return LeaderboardRow(
                rank: Int(number(r["rank"])),
                ownerId: owner,
                displayName: r["displayName"] as? String,
                squareMiles: number(r["squareMiles"]),
                points: Int(number(r["points"])),
                minutesDriven: Int(number(r["minutesDriven"])),
                state: r["state"] as? String,
                isMe: owner == uid)
        }
    }

    func myInviteCode() async throws -> String {
        let d = try await call("getMyInvite")
        return d["code"] as? String ?? ""
    }

    func addFriend(code: String) async throws -> FriendResult {
        let d = try await call("addFriend", ["code": code])
        return FriendResult(
            friendId: d["friendId"] as? String ?? "",
            displayName: d["displayName"] as? String ?? "Your friend")
    }

    func setDisplayName(_ name: String) async throws -> String {
        let d = try await call("setDisplayName", ["name": name])
        return d["displayName"] as? String ?? name
    }

    // MARK: Invite links

    /// The link friends tap. It only opens the app if they already have it installed.
    static func inviteLink(code: String) -> String { "loopd://invite/\(code)" }

    /// Handles loopd://invite/ABCD2345
    func handle(url: URL) {
        guard url.scheme == "loopd", url.host == "invite" else { return }
        let code = url.lastPathComponent.uppercased()
        guard code.count >= 6 else { return }
        pendingInvite = PendingInvite(code: code)
    }
}

/// A GPS fix with a timestamp, so the server can run anti-cheat speed checks.
struct TimedCoord {
    let coord: Coord
    let millis: Double
}
