import Foundation

extension GeoMath {
    /// True when `point` is inside the shape. `rings[0]` is the outer edge and any
    /// further rings are holes, the same layout the server stores.
    /// This is used to work out which piece of land a player tapped on the map.
    public static func contains(rings: [[Coord]], point: Coord) -> Bool {
        guard let outer = rings.first, isInside(outer, point) else { return false }
        for hole in rings.dropFirst() where isInside(hole, point) { return false }
        return true
    }

    /// Ray casting: count how many edges a line going east from the point crosses.
    /// An odd count means inside. Accurate at city scale, where the earth is close to flat.
    private static func isInside(_ ring: [Coord], _ p: Coord) -> Bool {
        guard ring.count >= 3 else { return false }
        var inside = false
        var j = ring.count - 1
        for i in 0..<ring.count {
            let a = ring[i], b = ring[j]
            if (a.lat > p.lat) != (b.lat > p.lat),
               p.lon < (b.lon - a.lon) * (p.lat - a.lat) / (b.lat - a.lat) + a.lon {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
