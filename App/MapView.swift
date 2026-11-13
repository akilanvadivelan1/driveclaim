import SwiftUI
import MapKit
import TerritoryCore

/// Which land to draw.
enum MapFilter: Equatable {
    case everyone          // the whole nation
    case mineAndFriends    // only you and your friends
}

/// What the player tapped on the map.
struct TerritorySelection: Equatable, Identifiable {
    enum Kind: Equatable { case mine, friend }
    let id: String          // the claim
    let ownerId: String
    let kind: Kind
    let squareMiles: Double
    let colorIndex: Int     // which friend color, so the card can match the map
}

/// Apple Maps (MapKit). No API key or billing account needed.
/// Your land is yellow and see-through, each friend gets a color, everyone else is grey,
/// and your live trail is white. Pinch to zoom, drag to move, tap land to see whose it is.
struct MapView: UIViewRepresentable {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var firebase: FirebaseService

    var filter: MapFilter = .everyone
    /// While driving, keep the map centered on the car. Dragging the map turns this off.
    @Binding var follow: Bool
    /// The land the player tapped, or nil.
    @Binding var selection: TerritorySelection?
    /// Change this number to fly back to the player's location.
    var recenterTrigger = 0
    /// Zoom out to fit the land being shown (used by the leaderboard map).
    var fitClaims = false

    /// How far across the map shows when it zooms to the player, in meters.
    static let closeUpMeters: Double = 5000

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.showsScale = true                  // shows miles, handy for square-mile land
        map.overrideUserInterfaceStyle = .dark

        let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = config

        // Start zoomed out over the continental U.S. until the player's location is known.
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 55)),
            animated: false)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let c = context.coordinator
        c.parent = self

        // 1. Land. Only rebuilt when the shown claims actually change.
        let visible = firebase.allClaims.filter { claim in
            switch filter {
            case .everyone: return true
            case .mineAndFriends:
                return claim.ownerId == firebase.uid || firebase.friendIds.contains(claim.ownerId)
            }
        }
        let key = "\(filter)|" + visible.map { "\($0.id):\($0.squareMiles)" }.joined(separator: ",")
            + "|" + firebase.friendIds.sorted().joined(separator: ",") + "|" + (firebase.uid ?? "")
        if key != c.claimsKey {
            c.claimsKey = key
            c.hitTargets = []
            map.removeOverlays(map.overlays.filter { $0 is MKPolygon })
            for claim in visible {
                let style = styleName(for: claim.ownerId)
                c.hitTargets.append(Coordinator.HitTarget(claim: claim, style: style))
                for rings in claim.polygons {
                    if let polygon = makePolygon(rings) {
                        polygon.title = style
                        map.addOverlay(polygon)
                    }
                }
            }
        }

        // 2. Zoom to fit the land once per filter (leaderboard map).
        if fitClaims && c.fittedFilter != filter {
            var rect = MKMapRect.null
            for overlay in map.overlays where overlay is MKPolygon {
                rect = rect.union(overlay.boundingMapRect)
            }
            if !rect.isNull {
                map.setVisibleMapRect(
                    rect,
                    edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                    animated: false)
                c.fittedFilter = filter
                c.didInitialCenter = true
            }
        }

        // 3. Fly back to the player when asked.
        if c.lastRecenter != recenterTrigger {
            c.lastRecenter = recenterTrigger
            if let location = map.userLocation.location {
                map.setRegion(
                    MKCoordinateRegion(center: location.coordinate,
                                       latitudinalMeters: Self.closeUpMeters,
                                       longitudinalMeters: Self.closeUpMeters),
                    animated: true)
            }
        }

        // 4. The live trail behind the car.
        if game.trail.count != c.trailCount {
            c.trailCount = game.trail.count
            if let old = c.trailLine { map.removeOverlay(old) }
            c.trailLine = nil
            if game.trail.count > 1 {
                var coords = game.trail.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
                let line = MKPolyline(coordinates: &coords, count: coords.count)
                map.addOverlay(line)
                c.trailLine = line
            }
        }

        // 5. Follow the car while driving.
        if follow, game.isDriving, let cur = game.current {
            let center = CLLocationCoordinate2D(latitude: cur.lat, longitude: cur.lon)
            if map.region.span.latitudeDelta > 0.05 {
                map.setRegion(
                    MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)),
                    animated: true)
            } else {
                map.setCenter(center, animated: true)
            }
        }
    }

    // MARK: Helpers

    /// "mine", "friend:2" or "other". The renderer and the tap handler read this.
    private func styleName(for ownerId: String) -> String {
        if ownerId == firebase.uid { return "mine" }
        if firebase.friendIds.contains(ownerId) {
            return "friend:\(Display.colorIndex(for: ownerId, count: Theme.friendPaletteUI.count))"
        }
        return "other"
    }

    private func makePolygon(_ rings: [[Coord]]) -> MKPolygon? {
        guard let outer = rings.first, outer.count >= 3 else { return nil }
        var outerCoords = outer.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
        let holes: [MKPolygon] = rings.dropFirst().compactMap { ring in
            guard ring.count >= 3 else { return nil }
            var coords = ring.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            return MKPolygon(coordinates: &coords, count: coords.count)
        }
        return MKPolygon(coordinates: &outerCoords, count: outerCoords.count,
                         interiorPolygons: holes.isEmpty ? nil : holes)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        struct HitTarget {
            let claim: FirebaseService.RemoteClaim
            let style: String
        }

        var parent: MapView?
        var claimsKey = ""
        var hitTargets: [HitTarget] = []
        var trailCount = -1
        var trailLine: MKPolyline?
        var fittedFilter: MapFilter?
        var didInitialCenter = false
        var lastRecenter = 0

        /// If the user drags or pinches the map, stop following the car.
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            guard let recognizers = mapView.subviews.first?.gestureRecognizers else { return }
            if recognizers.contains(where: { $0.state == .began || $0.state == .ended }) {
                DispatchQueue.main.async { self.parent?.follow = false }
            }
        }

        /// Zoom to the player the first time their location is known.
        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard !didInitialCenter, parent?.fitClaims != true, let loc = userLocation.location else { return }
            didInitialCenter = true
            mapView.setRegion(
                MKCoordinateRegion(center: loc.coordinate,
                                   latitudinalMeters: MapView.closeUpMeters,
                                   longitudinalMeters: MapView.closeUpMeters),
                animated: false)
        }

        // MARK: Taps

        /// Lets this tap work alongside the map's own gestures (pan, pinch, double tap).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let map = gesture.view as? MKMapView else { return }
            let c = map.convert(gesture.location(in: map), toCoordinateFrom: map)
            let tapped = Coord(lat: c.latitude, lon: c.longitude)

            for target in hitTargets where target.claim.polygons.contains(where: { GeoMath.contains(rings: $0, point: tapped) }) {
                if target.style == "mine" {
                    parent?.selection = TerritorySelection(
                        id: target.claim.id, ownerId: target.claim.ownerId, kind: .mine,
                        squareMiles: target.claim.squareMiles, colorIndex: 0)
                    return
                }
                if target.style.hasPrefix("friend:"), let index = Int(target.style.dropFirst(7)) {
                    parent?.selection = TerritorySelection(
                        id: target.claim.id, ownerId: target.claim.ownerId, kind: .friend,
                        squareMiles: target.claim.squareMiles, colorIndex: index)
                    return
                }
                break   // a stranger's land: nothing to show
            }
            parent?.selection = nil
        }

        // MARK: Drawing

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygon = overlay as? MKPolygon {
                let color: UIColor
                let name = polygon.title ?? "other"
                if name == "mine" {
                    color = Theme.mineUI
                } else if name.hasPrefix("friend:"), let i = Int(name.dropFirst(7)),
                          Theme.friendPaletteUI.indices.contains(i) {
                    color = Theme.friendPaletteUI[i]
                } else {
                    color = Theme.otherUI
                }
                let r = MKPolygonRenderer(polygon: polygon)
                let isOther = name == "other"
                let isMine = name == "mine"
                r.fillColor = color.withAlphaComponent(isMine ? 0.34 : (isOther ? 0.12 : 0.26))   // see-through
                r.strokeColor = color.withAlphaComponent(isOther ? 0.5 : 0.95)
                r.lineWidth = isMine ? 2.5 : 2
                return r
            }
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = .white
                r.lineWidth = 5
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
