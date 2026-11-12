import SwiftUI
import MapKit
import TerritoryCore

/// Which land to draw.
enum MapFilter: Equatable {
    case everyone          // the whole nation
    case mineAndFriends    // only you and your friends
}

/// Apple Maps (MapKit). No API key or billing account needed.
/// Your land is yellow and see-through, friends get their own colors,
/// everyone else is soft gray, and your live trail is white.
/// Pinch to zoom and drag to move around like any map.
struct MapView: UIViewRepresentable {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var firebase: FirebaseService

    var filter: MapFilter = .everyone
    /// While driving, keep the map centered on the car. Dragging the map turns this off.
    @Binding var follow: Bool
    /// Zoom out to fit the land being shown (used by the leaderboard map).
    var fitClaims = false

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

        // Start zoomed out over the continental U.S.
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 55)),
            animated: false)
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
            map.removeOverlays(map.overlays.filter { $0 is MKPolygon })
            for claim in visible {
                let style = styleName(for: claim.ownerId)
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

        // 3. The live trail behind the car.
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

        // 4. Follow the car while driving.
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

    /// "mine", "friend:2" or "other". The renderer reads this to pick a color.
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

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView?
        var claimsKey = ""
        var trailCount = -1
        var trailLine: MKPolyline?
        var fittedFilter: MapFilter?
        var didInitialCenter = false

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
                MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000),
                animated: false)
        }

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
