import Foundation

public enum Scoring {
    /// Points awarded per square mile claimed. Bigger loops earn more.
    public static let pointsPerSquareMile = 100.0
    /// Loops smaller than this are ignored (parking lots, roundabouts).
    public static let minimumSquareMiles = 0.02

    public static func points(forSquareMiles area: Double) -> Int {
        Int((area * pointsPerSquareMile).rounded())
    }
}

public struct Claim: Codable, Identifiable, Equatable {
    public let id: UUID
    public let ring: [Coord]
    public let squareMiles: Double
    public let points: Int
    public let date: Date

    public init(ring: [Coord], date: Date = Date()) {
        let area = GeoMath.areaSquareMiles(ring)
        self.id = UUID()
        self.ring = ring
        self.squareMiles = area
        self.points = Scoring.points(forSquareMiles: area)
        self.date = date
    }
}
