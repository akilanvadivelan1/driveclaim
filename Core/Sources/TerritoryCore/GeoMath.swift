import Foundation

public struct Coord: Codable, Equatable {
    public var lat: Double
    public var lon: Double
    public init(lat: Double, lon: Double) { self.lat = lat; self.lon = lon }
}

public enum GeoMath {
    public static let earthRadiusMeters = 6_371_008.8
    public static let metersPerSquareMile = 2_589_988.110336

    /// Project to local flat meters around an origin. Accurate for city-scale loops.
    static func project(_ c: Coord, origin: Coord) -> (x: Double, y: Double) {
        let latRad = origin.lat * .pi / 180
        let x = (c.lon - origin.lon) * .pi / 180 * earthRadiusMeters * cos(latRad)
        let y = (c.lat - origin.lat) * .pi / 180 * earthRadiusMeters
        return (x, y)
    }

    public static func distanceMeters(_ a: Coord, _ b: Coord) -> Double {
        let p = project(b, origin: a)
        return (p.x * p.x + p.y * p.y).squareRoot()
    }

    /// Polygon area in square miles (shoelace formula on a local projection).
    public static func areaSquareMiles(_ ring: [Coord]) -> Double {
        guard ring.count >= 3 else { return 0 }
        let origin = ring[0]
        let pts = ring.map { project($0, origin: origin) }
        var sum = 0.0
        for i in 0..<pts.count {
            let j = (i + 1) % pts.count
            sum += pts[i].x * pts[j].y - pts[j].x * pts[i].y
        }
        return abs(sum) / 2 / metersPerSquareMile
    }

    /// Intersection of segments p1-p2 and p3-p4. Returns the point and fraction along p1-p2.
    static func intersect(_ p1: Coord, _ p2: Coord, _ p3: Coord, _ p4: Coord) -> (point: Coord, t: Double)? {
        let a = project(p2, origin: p1)
        let c = project(p3, origin: p1)
        let d = project(p4, origin: p1)
        let r = a
        let s = (x: d.x - c.x, y: d.y - c.y)
        let denom = r.x * s.y - r.y * s.x
        if abs(denom) < 1e-9 { return nil }
        let t = (c.x * s.y - c.y * s.x) / denom
        let u = (c.x * r.y - c.y * r.x) / denom
        guard t >= 0, t <= 1, u >= 0, u <= 1 else { return nil }
        return (Coord(lat: p1.lat + (p2.lat - p1.lat) * t, lon: p1.lon + (p2.lon - p1.lon) * t), t)
    }
}
