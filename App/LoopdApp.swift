import SwiftUI
import FirebaseCore

@main
struct LoopdApp: App {
    // One FirebaseService, shared with the GameStore so both see the same
    // auth session and live listeners.
    @StateObject private var firebase: FirebaseService
    @StateObject private var game: GameStore

    init() {
        // Only configure Firebase if its config file is present, so the UI can
        // be previewed in the simulator before the backend is set up.
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }

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
                .onOpenURL { firebase.handle(url: $0) }
        }
    }
}
