/**
 * Pure territory logic: build a loop from a GPS trail and resolve stealing.
 * No Firebase in here, so it can be tested with plain Node.
 *
 * Geometry is stored in Firestore as a GeoJSON string (not nested arrays,
 * because Firestore does not allow arrays inside arrays).
 */
const turf = require("@turf/turf");

const SQ_METERS_PER_SQ_MILE = 2589988.110336;
const MIN_STEAL_SQ_MILES = 0.001;

function sqMiles(feature) {
  return turf.area(feature) / SQ_METERS_PER_SQ_MILE;
}

/**
 * Build the claimed area from a trail of {lat, lon, t}.
 * The route is closed with a straight line from the end back to the start.
 * If the route crosses itself (a figure 8), each lobe is kept.
 * Returns a Polygon or MultiPolygon Feature, or null if it cannot be built.
 */
function loopFromTrail(trail) {
  try {
    const ring = trail.map((p) => [p.lon, p.lat]);
    ring.push(ring[0]);
    let poly = turf.cleanCoords(turf.rewind(turf.polygon([ring])));

    // Split self-crossing routes into simple pieces.
    const pieces = turf.unkinkPolygon(poly).features.filter((f) => turf.area(f) > 1);
    if (pieces.length === 0) return null;
    poly = pieces.length === 1
      ? pieces[0]
      : turf.multiPolygon(pieces.map((f) => f.geometry.coordinates));

    // Keep stored documents small: ~3 meter simplification, 6 decimal places.
    poly = turf.simplify(poly, { tolerance: 0.00003, highQuality: false, mutate: false });
    poly = turf.truncate(poly, { precision: 6, mutate: false });
    return poly;
  } catch (e) {
    return null;
  }
}

function toFeature(geometry) {
  return turf.feature(geometry);
}

function serialize(feature) {
  return JSON.stringify(feature.geometry);
}

function parse(geometryString) {
  try {
    const g = JSON.parse(geometryString);
    if (g.type !== "Polygon" && g.type !== "MultiPolygon") return null;
    return toFeature(g);
  } catch (e) {
    return null;
  }
}

/**
 * Work out what the thief takes from everyone else.
 * claims: [{ id, ownerId, state, geometry: <GeoJSON string> }]
 * Returns { stolenSqMiles, edits } where each edit is one of:
 *   { type: "delete", id, ownerId, state, lost }
 *   { type: "shrink", id, ownerId, state, lost, geometry: <string>, squareMiles }
 */
function resolveSteals(loop, thiefId, claims) {
  const edits = [];
  let stolenSqMiles = 0;

  for (const c of claims) {
    if (c.ownerId === thiefId) continue; // cannot steal from yourself
    const victim = parse(c.geometry);
    if (!victim) continue;

    let overlap;
    try {
      overlap = turf.intersect(turf.featureCollection([loop, victim]));
    } catch (e) {
      continue; // bad geometry, skip rather than fail the whole drive
    }
    if (!overlap) continue;

    const lost = sqMiles(overlap);
    if (lost < MIN_STEAL_SQ_MILES) continue;

    let remainder = null;
    try {
      remainder = turf.difference(turf.featureCollection([victim, loop]));
    } catch (e) {
      continue; // could not subtract cleanly, so leave their land alone
    }

    stolenSqMiles += lost;
    const remaining = remainder ? sqMiles(remainder) : 0;
    if (!remainder || remaining < MIN_STEAL_SQ_MILES) {
      edits.push({ type: "delete", id: c.id, ownerId: c.ownerId, state: c.state, lost });
    } else {
      edits.push({
        type: "shrink",
        id: c.id,
        ownerId: c.ownerId,
        state: c.state,
        lost,
        geometry: serialize(remainder),
        squareMiles: remaining,
      });
    }
  }
  return { stolenSqMiles, edits };
}

/**
 * Remove land the player already owns from their new loop, so driving the same
 * loop twice cannot score twice. Returns the new-land feature, or null if the
 * loop adds nothing.
 * ownGeometries: array of GeoJSON strings for the player's existing claims.
 */
function subtractOwnLand(loop, ownGeometries) {
  let land = loop;
  for (const g of ownGeometries) {
    const own = parse(g);
    if (!own) continue;
    try {
      land = turf.difference(turf.featureCollection([land, own]));
    } catch (e) {
      continue;
    }
    if (!land) return null;
  }
  return land;
}

module.exports = {
  subtractOwnLand,
  SQ_METERS_PER_SQ_MILE,
  sqMiles,
  loopFromTrail,
  serialize,
  parse,
  resolveSteals,
};
