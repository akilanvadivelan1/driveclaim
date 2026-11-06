/**
 * DriveClaim server-authoritative game logic.
 *
 * The phone NEVER writes claims or scores directly. It calls `submitDrive`
 * with the raw GPS trail. The server runs anti-cheat, builds the loop,
 * resolves stealing against existing claims, derives the US state, and writes
 * everything in one transaction. This is what stops players posting fake
 * polygons for free points or faking which state they are competing in.
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const turf = require("@turf/turf"); // robust geo polygon ops (concave + holes)
const { validateTrail } = require("./anticheat");
const { stateForPoint } = require("./usstate");

admin.initializeApp();
const db = admin.firestore();

const SQ_METERS_PER_SQ_MILE = 2589988.110336;
const MIN_SQ_MILES = 0.02;

function sqMiles(feature) {
  return turf.area(feature) / SQ_METERS_PER_SQ_MILE;
}

// Build a closed polygon from the trail. Expects points with {lat, lon, t}.
function loopFromTrail(trail) {
  const ring = trail.map((p) => [p.lon, p.lat]);
  ring.push(ring[0]); // close it
  try {
    return turf.cleanCoords(turf.rewind(turf.polygon([ring])));
  } catch (e) {
    return null;
  }
}

exports.submitDrive = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }
  const uid = context.auth.uid;
  const trail = data.trail;

  // 1. Anti-cheat: shape, timing, speed, acceleration, real movement.
  const verdict = validateTrail(trail || []);
  if (!verdict.ok) {
    throw new functions.https.HttpsError("failed-precondition", verdict.reason);
  }

  // 2. Build and size the loop.
  const loop = loopFromTrail(trail);
  if (!loop) {
    throw new functions.https.HttpsError("invalid-argument", "That drive did not form a loop.");
  }
  const loopArea = sqMiles(loop);
  if (loopArea < MIN_SQ_MILES) {
    throw new functions.https.HttpsError("failed-precondition", "Loop too small to claim.");
  }

  // 3. Server-derived state from the loop centroid. Client cannot fake this.
  const center = turf.centroid(loop).geometry.coordinates; // [lon, lat]
  const stateCode = stateForPoint(center[0], center[1]);

  const existing = await db.collection("claims").get(); // v1: scan. Add geohash index later.

  const result = await db.runTransaction(async (tx) => {
    let gainedArea = 0;
    const edits = [];

    existing.forEach((doc) => {
      const c = doc.data();
      if (c.ownerId === uid) return; // can't steal from yourself
      let victim;
      try {
        victim = turf.polygon(c.geometry);
      } catch (e) {
        return;
      }
      const overlap = turf.intersect(loop, victim);
      if (!overlap) return;

      const stolen = sqMiles(overlap);
      if (stolen < 0.001) return;

      const remainder = turf.difference(victim, loop);
      gainedArea += stolen;

      if (!remainder) {
        edits.push({ type: "delete", ref: doc.ref, victimId: c.ownerId, victimState: c.state, lost: stolen });
      } else {
        edits.push({
          type: "shrink",
          ref: doc.ref,
          geometry: remainder.geometry.coordinates,
          area: sqMiles(remainder),
          victimId: c.ownerId,
          victimState: c.state,
          lost: stolen,
        });
      }
    });

    // Thief owns the full loop (empty land plus captured land).
    const myClaimRef = db.collection("claims").doc();
    tx.set(myClaimRef, {
      ownerId: uid,
      geometry: loop.geometry.coordinates,
      squareMiles: loopArea,
      state: stateCode,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Build per-player and per-player-per-state score deltas.
    // nationalDelta[uid] -> total sq mi change
    // stateDelta[`${uid}|${ST}`] -> sq mi change within that state
    const nationalDelta = {};
    const stateDelta = {};
    const addNat = (u, d) => { nationalDelta[u] = (nationalDelta[u] || 0) + d; };
    const addState = (u, st, d) => {
      const k = `${u}|${st || "US"}`;
      stateDelta[k] = (stateDelta[k] || 0) + d;
    };

    addNat(uid, loopArea);
    addState(uid, stateCode, loopArea);

    for (const e of edits) {
      if (e.type === "delete") {
        tx.delete(e.ref);
      } else {
        tx.update(e.ref, { geometry: e.geometry, squareMiles: e.area });
      }
      addNat(e.victimId, -e.lost);
      addState(e.victimId, e.victimState, -e.lost);
    }

    // National leaderboard doc per player.
    for (const [player, delta] of Object.entries(nationalDelta)) {
      tx.set(
        db.collection("players").doc(player),
        { squareMiles: admin.firestore.FieldValue.increment(delta) },
        { merge: true }
      );
    }

    // State leaderboard doc per (player, state): collection "leaderboard_state".
    for (const [key, delta] of Object.entries(stateDelta)) {
      const [player, st] = key.split("|");
      tx.set(
        db.collection("leaderboard_state").doc(`${st}_${player}`),
        {
          ownerId: player,
          state: st,
          squareMiles: admin.firestore.FieldValue.increment(delta),
        },
        { merge: true }
      );
    }

    return { claimedSquareMiles: loopArea, stolenSquareMiles: gainedArea, state: stateCode };
  });

  return result;
});

/**
 * Read-only leaderboard fetch. scope = "national" or "state".
 * For "state", pass { state: "CA" }. Returns top N by square miles.
 */
exports.leaderboard = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Sign in first.");
  }
  const scope = data.scope === "state" ? "state" : "national";
  const limit = Math.min(Math.max(parseInt(data.limit || 50, 10), 1), 100);

  let query;
  if (scope === "state") {
    const st = String(data.state || "US").toUpperCase();
    query = db.collection("leaderboard_state")
      .where("state", "==", st)
      .orderBy("squareMiles", "desc")
      .limit(limit);
  } else {
    query = db.collection("players")
      .orderBy("squareMiles", "desc")
      .limit(limit);
  }

  const snap = await query.get();
  const rows = snap.docs.map((d, i) => {
    const v = d.data();
    return {
      rank: i + 1,
      ownerId: v.ownerId || d.id,
      squareMiles: v.squareMiles || 0,
      state: v.state || null,
    };
  });
  return { scope, rows };
});
