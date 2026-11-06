import Foundation

/// Tracks a driving trail. When the trail crosses itself, the enclosed loop becomes a Claim.
public final class LoopDetector {
    public private(set) var trail: [Coord] = []
    /// Only record a new point after moving at least this far.
    public var minStepMeters = 20.0

    public init() {}

    public func reset() { trail.removeAll() }

    /// Add a GPS point. Returns a Claim if this point closed a big enough loop.
    public func add(_ point: Coord) -> Claim? {
        guard let last = trail.last else { trail = [point]; return nil }
        if GeoMath.distanceMeters(last, point) < minStepMeters { return nil }

        // Check the new segment (last -> point) against older, non-adjacent segments.
        if trail.count >= 3 {
            for i in 0..<(trail.count - 2) {
                guard let hit = GeoMath.intersect(trail[i], trail[i + 1], last, point) else { continue }
                var ring = [hit.point]
                ring.append(contentsOf: trail[(i + 1)...])
                let claim = Claim(ring: ring)
                // Restart the trail from the crossing point either way.
                trail = [hit.point, point]
                return claim.squareMiles >= Scoring.minimumSquareMiles ? claim : nil
            }
        }
        trail.append(point)
        return nil
    }
}
