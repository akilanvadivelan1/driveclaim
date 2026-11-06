import Foundation

/// Polygon overlap and subtraction, used to resolve stealing.
///
/// A player's new loop (the "thief") overlaps another player's claim (the
/// "victim"). We compute:
///   - the intersection  -> the piece that changes hands
///   - victim minus thief -> what the victim keeps
///
/// Math runs in a local flat projection around a shared origin, which is
/// accurate at city scale. All rings are simple polygons (no holes).
public enum PolygonClip {

    struct Pt: Equatable { var x: Double; var y: Double }

    // MARK: Projection helpers

    static func toXY(_ ring: [Coord], origin: Coord) -> [Pt] {
        ring.map { c in
            let p = GeoMath_project(c, origin: origin)
            return Pt(x: p.x, y: p.y)
        }
    }

    static func toCoord(_ p: Pt, origin: Coord) -> Coord {
        let latRad = origin.lat * .pi / 180
        let lat = origin.lat + (p.y / GeoMath.earthRadiusMeters) * 180 / .pi
        let lon = origin.lon + (p.x / (GeoMath.earthRadiusMeters * cos(latRad))) * 180 / .pi
        return Coord(lat: lat, lon: lon)
    }

    static func signedArea(_ poly: [Pt]) -> Double {
        guard poly.count >= 3 else { return 0 }
        var s = 0.0
        for i in 0..<poly.count {
            let j = (i + 1) % poly.count
            s += poly[i].x * poly[j].y - poly[j].x * poly[i].y
        }
        return s / 2
    }

    static func ensureCCW(_ poly: [Pt]) -> [Pt] { signedArea(poly) < 0 ? poly.reversed() : poly }
    static func ensureCW(_ poly: [Pt]) -> [Pt] { signedArea(poly) > 0 ? poly.reversed() : poly }

    // MARK: Intersection (Sutherland–Hodgman)

    /// Clip `subject` by the convex-or-concave `clip` polygon.
    /// Sutherland–Hodgman is exact when `clip` is convex; for city loops that
    /// are roughly convex it is a good approximation. Good enough for v1 steal
    /// resolution; we can swap in Weiler–Atherton later for concave clips.
    static func clip(_ subject: [Pt], by clipPoly: [Pt]) -> [Pt] {
        let clip = ensureCCW(clipPoly)
        var output = subject
        for i in 0..<clip.count {
            guard !output.isEmpty else { break }
            let a = clip[i]
            let b = clip[(i + 1) % clip.count]
            let input = output
            output = []
            for j in 0..<input.count {
                let cur = input[j]
                let prev = input[(j + input.count - 1) % input.count]
                let curIn = inside(cur, a, b)
                let prevIn = inside(prev, a, b)
                if curIn {
                    if !prevIn, let x = lineIntersect(prev, cur, a, b) { output.append(x) }
                    output.append(cur)
                } else if prevIn, let x = lineIntersect(prev, cur, a, b) {
                    output.append(x)
                }
            }
        }
        return output
    }

    static func inside(_ p: Pt, _ a: Pt, _ b: Pt) -> Bool {
        (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) >= 0
    }

    static func lineIntersect(_ p1: Pt, _ p2: Pt, _ p3: Pt, _ p4: Pt) -> Pt? {
        let d = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
        if abs(d) < 1e-12 { return nil }
        let a = p1.x * p2.y - p1.y * p2.x
        let b = p3.x * p4.y - p3.y * p4.x
        let x = (a * (p3.x - p4.x) - (p1.x - p2.x) * b) / d
        let y = (a * (p3.y - p4.y) - (p1.y - p2.y) * b) / d
        return Pt(x: x, y: y)
    }

    // MARK: Public API

    /// The overlapping region of two claims, as a ring (empty if they don't overlap).
    public static func intersection(_ thief: [Coord], _ victim: [Coord]) -> [Coord] {
        guard thief.count >= 3, victim.count >= 3 else { return [] }
        let origin = victim[0]
        let subj = ensureCCW(toXY(victim, origin: origin))
        let clipP = ensureCCW(toXY(thief, origin: origin))
        let result = clip(subj, by: clipP)
        guard result.count >= 3, abs(signedArea(result)) > 1e-6 else { return [] }
        return result.map { toCoord($0, origin: origin) }
    }

    /// Area in square miles of the intersection. This is the thief's reward.
    public static func stolenSquareMiles(thief: [Coord], victim: [Coord]) -> Double {
        GeoMath.areaSquareMiles(intersection(thief, victim))
    }

    /// How much area the victim keeps after the steal (victim total minus overlap).
    public static func remainingSquareMiles(victim: [Coord], stolen: [Coord]) -> Double {
        max(0, GeoMath.areaSquareMiles(victim) - GeoMath.areaSquareMiles(stolen))
    }
}

/// Internal bridge to GeoMath's private projection without widening its API.
func GeoMath_project(_ c: Coord, origin: Coord) -> (x: Double, y: Double) {
    let latRad = origin.lat * .pi / 180
    let x = (c.lon - origin.lon) * .pi / 180 * GeoMath.earthRadiusMeters * cos(latRad)
    let y = (c.lat - origin.lat) * .pi / 180 * GeoMath.earthRadiusMeters
    return (x, y)
}
