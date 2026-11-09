import SwiftUI
import MapKit
import TerritoryCore

/// Apple Maps (MapKit). No API key or billing account needed.
/// Your land is green, rivals are red, and your live trail is blue.
struct MapView: UIViewRepresentable {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var firebase: FirebaseService

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        // Start zoomed out over the continental U.S.
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.35),
                span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 55)),
            animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.removeOverlays(map.overlays)

        for claim in firebase.allClaims {
            var coords = claim.ring.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            let poly = MKPolygon(coordinates: &coords, count: coords.count)
            poly.title = claim.ownerId == firebase.uid ? "mine" : "rival"
            map.addOverlay(poly)
        }

        if game.trail.count > 1 {
            var coords = game.trail.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
            map.addOverlay(MKPolyline(coordinates: &coords, count: coords.count))
        }

        if let c = game.current, game.isDriving {
            map.setCenter(CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon), animated: true)
            if map.region.span.latitudeDelta > 0.05 {
                map.setRegion(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon),
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)),
                    animated: true)
            }
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolygon {
                let r = MKPolygonRenderer(polygon: poly)
                let color: UIColor = poly.title == "mine" ? .systemGreen : .systemRed
                r.fillColor = color.withAlphaComponent(0.30)
                r.strokeColor = color
                r.lineWidth = 2
                return r
            }
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = .systemBlue
                r.lineWidth = 5
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
