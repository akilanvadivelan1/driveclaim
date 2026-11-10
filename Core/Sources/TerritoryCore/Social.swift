import Foundation

/// Reads the GeoJSON string the server stores for each claim.
/// A claim is a list of polygons. Each polygon is a list of rings,
/// where the first ring is the outer edge and any others are holes.
public enum GeoJSONGeometry {
    public static func parsePolygons(_ json: String) -> [[[Coord]]] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String,
              let coordinates = object["coordinates"] else { return [] }

        func ring(_ any: Any) -> [Coord] {
            guard let points = any as? [Any] else { return [] }
            return points.compactMap { point in
                guard let pair = point as? [Any], pair.count >= 2,
                      let lon = (pair[0] as? NSNumber)?.doubleValue,
                      let lat = (pair[1] as? NSNumber)?.doubleValue else { return nil }
                return Coord(lat: lat, lon: lon)
            }
        }
        func polygon(_ any: Any) -> [[Coord]] {
            guard let rings = any as? [Any] else { return [] }
            return rings.map(ring).filter { $0.count >= 3 }
        }

        switch type {
        case "Polygon":
            let p = polygon(coordinates)
            return p.isEmpty ? [] : [p]
        case "MultiPolygon":
            guard let polys = coordinates as? [Any] else { return [] }
            return polys.map(polygon).filter { !$0.isEmpty }
        default:
            return []
        }
    }
}

/// Small display helpers shared by the app screens.
public enum Display {
    /// 45 -> "45 min", 125 -> "2h 05m".
    public static func minutes(_ total: Int) -> String {
        let m = max(0, total)
        if m < 60 { return "\(m) min" }
        return "\(m / 60)h " + String(format: "%02dm", m % 60)
    }

    /// A stable color slot for a player id. Swift's hashValue changes between
    /// launches, so this adds up the characters instead.
    public static func colorIndex(for id: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let sum = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 1_000_003 }
        return sum % count
    }
}
