import SwiftUI
import GoogleMaps
import TerritoryCore

struct MapView: UIViewRepresentable {
    @EnvironmentObject var game: GameStore
    @EnvironmentObject var firebase: FirebaseService

    func makeUIView(context: Context) -> GMSMapView {
        let map = GMSMapView()
        map.isMyLocationEnabled = true
        map.settings.myLocationButton = true
        map.camera = GMSCameraPosition(latitude: 39.5, longitude: -98.35, zoom: 4) // center of the U.S.
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        map.clear()

        // Everyone's land. Mine is green, rivals are red.
        for claim in firebase.allClaims {
            let path = GMSMutablePath()
            claim.ring.forEach { path.add(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
            let poly = GMSPolygon(path: path)
            let mine = claim.ownerId == firebase.uid
            poly.fillColor = (mine ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.30)
            poly.strokeColor = mine ? .systemGreen : .systemRed
            poly.strokeWidth = 2
            poly.map = map
        }

        // Live trail of the drive in progress.
        if game.trail.count > 1 {
            let path = GMSMutablePath()
            game.trail.forEach { path.add(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
            let line = GMSPolyline(path: path)
            line.strokeColor = .systemBlue
            line.strokeWidth = 5
            line.map = map
        }

        if let c = game.current, game.isDriving {
            map.animate(to: GMSCameraPosition(latitude: c.lat, longitude: c.lon, zoom: 15))
        }
    }
}
