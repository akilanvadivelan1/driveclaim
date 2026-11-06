import Foundation
import CoreLocation
import AVFoundation
import TerritoryCore

/// Owns GPS, records the drive, submits it to the server, and speaks results.
/// In multiplayer, scoring and stealing happen on the server, so this class
/// only records the trail and shows a live local preview of the current loop.
final class GameStore: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var trail: [Coord] = []
    @Published var current: Coord?
    @Published var speedMph: Double = 0
    @Published var isDriving = false
    @Published var statusMessage: String?
    @Published var submitting = false

    private var recorded: [TimedCoord] = []
    private let manager = CLLocationManager()
    private let detector = LoopDetector()      // local preview of the current loop only
    private let speech = AVSpeechSynthesizer()
    private let firebase: FirebaseService

    init(firebase: FirebaseService) {
        self.firebase = firebase
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.requestAlwaysAuthorization()
        detector.reset()
        trail = []
        recorded = []
        manager.startUpdatingLocation()
        isDriving = true
        say("Territory started. Drive a loop to claim land. Loop through a rival to steal theirs.")
    }

    func end() {
        manager.stopUpdatingLocation()
        isDriving = false
        Task { await submit() }
    }

    private func submit() async {
        guard recorded.count >= 4 else { say("Not enough of a drive to claim anything."); return }
        submitting = true
        defer { submitting = false }
        do {
            let r = try await firebase.submitDrive(recorded)
            let base = String(format: "You claimed %.2f square miles.", r.claimed)
            let steal = r.stolen > 0.001 ? String(format: " You stole %.2f from rivals.", r.stolen) : ""
            let msg = base + steal
            statusMessage = msg
            say(msg)
        } catch {
            statusMessage = "Drive rejected: \(error.localizedDescription)"
            say("Your drive could not be claimed.")
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for loc in locations where loc.horizontalAccuracy >= 0 && loc.horizontalAccuracy < 50 {
            let c = Coord(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
            current = c
            speedMph = max(0, loc.speed) * 2.23694
            recorded.append(TimedCoord(coord: c, millis: loc.timestamp.timeIntervalSince1970 * 1000))
            _ = detector.add(c)
            trail = detector.trail
        }
    }

    private func say(_ text: String) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        speech.speak(AVSpeechUtterance(string: text))
    }
}
