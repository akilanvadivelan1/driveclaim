import XCTest
@testable import TerritoryCore

final class TerritoryCoreTests: XCTestCase {
    func testOneSquareMileArea() {
        // About 1 mile = 1609.344 m. Build a square near Denver.
        let o = Coord(lat: 39.74, lon: -104.99)
        let dLat = 1609.344 / GeoMath.earthRadiusMeters * 180 / .pi
        let dLon = dLat / cos(o.lat * .pi / 180)
        let ring = [o,
                    Coord(lat: o.lat, lon: o.lon + dLon),
                    Coord(lat: o.lat + dLat, lon: o.lon + dLon),
                    Coord(lat: o.lat + dLat, lon: o.lon)]
        XCTAssertEqual(GeoMath.areaSquareMiles(ring), 1.0, accuracy: 0.01)
        XCTAssertEqual(Scoring.points(forSquareMiles: 1.0), 1000)
    }

    func testLoopClosesAndClaims() {
        let d = LoopDetector()
        let o = Coord(lat: 39.74, lon: -104.99)
        let s = 0.005 // roughly 0.3 miles per side
        let path = [o,
                    Coord(lat: o.lat, lon: o.lon + s),
                    Coord(lat: o.lat + s, lon: o.lon + s),
                    Coord(lat: o.lat + s, lon: o.lon),
                    Coord(lat: o.lat - 0.001, lon: o.lon + s / 2)] // crosses the first leg
        var claim: Claim?
        for p in path { claim = d.add(p) ?? claim }
        XCTAssertNotNil(claim)
        XCTAssertGreaterThan(claim!.points, 0)
    }
}

extension TerritoryCoreTests {
    /// Two 1-mile squares offset by half a mile overlap in a 0.5 x 1 = 0.5 sq mi strip.
    func testStealOverlapArea() {
        let o = Coord(lat: 39.74, lon: -104.99)
        let mile = 1609.344
        let dLat = mile / GeoMath.earthRadiusMeters * 180 / .pi
        let dLon = dLat / cos(o.lat * .pi / 180)

        func square(offsetMiles: Double) -> [Coord] {
            let ox = dLon * offsetMiles
            return [Coord(lat: o.lat, lon: o.lon + ox),
                    Coord(lat: o.lat, lon: o.lon + ox + dLon),
                    Coord(lat: o.lat + dLat, lon: o.lon + ox + dLon),
                    Coord(lat: o.lat + dLat, lon: o.lon + ox)]
        }

        let victim = square(offsetMiles: 0)     // 1 sq mi
        let thief = square(offsetMiles: 0.5)    // shifted half a mile east

        let stolen = PolygonClip.stolenSquareMiles(thief: thief, victim: victim)
        XCTAssertEqual(stolen, 0.5, accuracy: 0.02)

        let remaining = PolygonClip.remainingSquareMiles(
            victim: victim, stolen: PolygonClip.intersection(thief, victim))
        XCTAssertEqual(remaining, 0.5, accuracy: 0.02)
    }

    func testNoOverlapStealsNothing() {
        let o = Coord(lat: 39.74, lon: -104.99)
        let far = Coord(lat: 40.0, lon: -104.0)
        let a = [o, Coord(lat: o.lat, lon: o.lon + 0.01),
                 Coord(lat: o.lat + 0.01, lon: o.lon + 0.01), Coord(lat: o.lat + 0.01, lon: o.lon)]
        let b = [far, Coord(lat: far.lat, lon: far.lon + 0.01),
                 Coord(lat: far.lat + 0.01, lon: far.lon + 0.01), Coord(lat: far.lat + 0.01, lon: far.lon)]
        XCTAssertEqual(PolygonClip.stolenSquareMiles(thief: b, victim: a), 0, accuracy: 1e-6)
    }
}

/// These strings were produced by the real server code (territory.js), so the
/// app and the backend are proven to agree on the stored format.
extension TerritoryCoreTests {
    private var serverPolygon: String {
        #"{"type":"Polygon","coordinates":[[[-104.99,39.74],[-104.971178,39.74],[-104.971178,39.754473],[-104.99,39.754473],[-104.99,39.74]]]}"#
    }
    private var serverMultiPolygon: String {
        #"{"type":"MultiPolygon","coordinates":[[[[-104.99,39.74],[-104.971178,39.74],[-104.971178,39.754473],[-104.99,39.754473],[-104.99,39.74]]],[[[-104.933534,39.74],[-104.914712,39.74],[-104.914712,39.754473],[-104.933534,39.754473],[-104.933534,39.74]]]]}"#
    }
    private var polygonWithHole: String {
        #"{"type":"Polygon","coordinates":[[[0,0],[0,4],[4,4],[4,0],[0,0]],[[1,1],[1,2],[2,2],[2,1],[1,1]]]}"#
    }

    func testParsesServerPolygon() {
        let polys = GeoJSONGeometry.parsePolygons(serverPolygon)
        XCTAssertEqual(polys.count, 1)
        XCTAssertEqual(polys[0].count, 1)
        // GeoJSON is [lon, lat], so the first point must be lat 39.74, lon -104.99.
        XCTAssertEqual(polys[0][0][0].lat, 39.74, accuracy: 1e-9)
        XCTAssertEqual(polys[0][0][0].lon, -104.99, accuracy: 1e-9)
        XCTAssertEqual(GeoMath.areaSquareMiles(polys[0][0]), 1.0, accuracy: 0.02)
    }

    func testParsesMultiPolygonAndHoles() {
        XCTAssertEqual(GeoJSONGeometry.parsePolygons(serverMultiPolygon).count, 2)
        let holey = GeoJSONGeometry.parsePolygons(polygonWithHole)
        XCTAssertEqual(holey.count, 1)
        XCTAssertEqual(holey[0].count, 2, "outer ring plus one hole")
    }

    func testBadGeometryParsesToNothing() {
        XCTAssertTrue(GeoJSONGeometry.parsePolygons("not json").isEmpty)
        XCTAssertTrue(GeoJSONGeometry.parsePolygons(#"{"type":"Point","coordinates":[1,2]}"#).isEmpty)
    }

    func testMinutesAndColorHelpers() {
        XCTAssertEqual(Display.minutes(0), "0 min")
        XCTAssertEqual(Display.minutes(45), "45 min")
        XCTAssertEqual(Display.minutes(125), "2h 05m")
        XCTAssertEqual(Display.minutes(-5), "0 min")
        XCTAssertEqual(Display.colorIndex(for: "abc123", count: 4), Display.colorIndex(for: "abc123", count: 4))
        XCTAssertTrue((0..<4).contains(Display.colorIndex(for: "someUserId", count: 4)))
        XCTAssertEqual(Display.colorIndex(for: "x", count: 0), 0)
    }
}

extension TerritoryCoreTests {
    func testPointRateMatchesTheServer() {
        // Firebase/functions/social.js uses 1000 per square mile. Keep these in step.
        XCTAssertEqual(Scoring.pointsPerSquareMile, 1000)
        XCTAssertEqual(Scoring.points(forSquareMiles: 0.35), 350)
    }

    func testSmallestLoopPoints() {
        XCTAssertEqual(Scoring.points(forSquareMiles: Scoring.minimumSquareMiles), 20)
    }
}
