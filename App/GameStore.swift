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
    /// Live numbers for the drive in progress.
    @Published var driveMiles: Double = 0
    @Published var driveStartedAt: Date?

    private var recorded: [TimedCoord] = []
    private let manager = CLLocationManager()
    private let detector = LoopDetector()      // local preview of the current loop only
    /// Created and used only on audioQueue, because starting speech touches the audio session.
    private var speech: AVSpeechSynthesizer?
    /// Audio session calls can block, so they run here and never on the main thread.
    private let audioQueue = DispatchQueue(label: "app.loopd.audio")
    private var audioConfigured = false
    private let firebase: FirebaseService

    init(firebase: FirebaseService) {
        self.firebase = firebase
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .automotiveNavigation
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.requestAlwaysAuthorization()
        detector.reset()
        trail = []
        recorded = []
        driveMiles = 0
        driveStartedAt = Date()
        manager.startUpdatingLocation()
        isDriving = true
        say("Territory started. Drive a loop to claim land. Loop through a rival to steal theirs.")
    }

    func end() {
        manager.stopUpdatingLocation()
        isDriving = false
        driveStartedAt = nil
        Task { await submit() }
    }

    @MainActor
    private func submit() async {
        guard recorded.count >= 4 else { say("Not enough of a drive to claim anything."); return }
        submitting = true
        defer { submitting = false }
        do {
            let r = try await firebase.submitDrive(recorded)
            let base = String(format: "You claimed %.2f square miles for %d points.", r.claimedSquareMiles, r.claimedPoints)
            let steal = r.stolenSquareMiles > 0.001
                ? String(format: " You took %.2f square miles from rivals.", r.stolenSquareMiles)
                : ""
            let msg = base + steal
            statusMessage = msg
            say(msg)
        } catch {
            statusMessage = "Drive rejected: \(error.localizedDescription)"
            say("Your drive could not be claimed.")
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isDriving else { return }
        for loc in locations {
            speedMph = max(0, loc.speed) * 2.23694
            guard let c = acceptedCoord(for: loc) else { continue }
            current = c
            recorded.append(TimedCoord(coord: c, millis: loc.timestamp.timeIntervalSince1970 * 1000))
            _ = detector.add(c)
            trail = detector.trail
        }
    }

    /// Throws out GPS readings that would make an honest drive look like cheating.
    /// Returns the position to record, or nil to skip this reading.
    private func acceptedCoord(for loc: CLLocation) -> Coord? {
        // Skip readings with no position or a poor signal.
        guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy <= 30 else { return nil }

        // iPhones often hand over an old, cached location first. Skip anything from
        // before this drive started. (Readings can arrive late when the screen is off,
        // so age alone is not a reason to skip one.)
        guard let started = driveStartedAt, loc.timestamp >= started.addingTimeInterval(-1) else { return nil }

        let c = Coord(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)

        if let last = recorded.last {
            let seconds = loc.timestamp.timeIntervalSince1970 - last.millis / 1000
            guard seconds > 0 else { return nil }
            let meters = GeoMath.distanceMeters(last.coord, c)

            // Skip a jump no car could make, which is a bad reading and not real movement.
            if meters / seconds * 2.23694 > 130 { return nil }

            // Skip tiny wobbles while parked, but still record a point every 10 seconds
            // so the server never sees a long silent gap at a red light.
            if meters < 8 && seconds < 10 { return nil }

            driveMiles += meters / 1609.344
        }
        return c
    }

    /// Speaks a short update. The audio session is set up once, off the main thread,
    /// and music is lowered while the voice talks.
    private func say(_ text: String) {
        audioQueue.async { [weak self] in
            guard let self else { return }
            let session = AVAudioSession.sharedInstance()
            if !self.audioConfigured {
                try? session.setCategory(.playback, mode: .voicePrompt,
                                         options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
                self.audioConfigured = true
            }
            try? session.setActive(true)
            if self.speech == nil {
                let synth = AVSpeechSynthesizer()
                synth.delegate = self
                self.speech = synth
            }
            self.speech?.speak(AVSpeechUtterance(string: text))
        }
    }
}

extension GameStore: AVSpeechSynthesizerDelegate {
    /// Hands the audio back so music returns to full volume.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        audioQueue.async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
