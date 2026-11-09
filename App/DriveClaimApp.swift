import SwiftUI
import FirebaseCore

@main
struct DriveClaimApp: App {
    // One FirebaseService, shared with the GameStore so both see the same
    // auth session and live listeners.
    @StateObject private var firebase: FirebaseService
    @StateObject private var game: GameStore

    init() {
        FirebaseApp.configure()

        let fb = FirebaseService()
        _firebase = StateObject(wrappedValue: fb)
        _game = StateObject(wrappedValue: GameStore(firebase: fb))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .environmentObject(firebase)
                .onAppear { firebase.signInIfNeeded() }
        }
    }
}
