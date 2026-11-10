/**
 * DriveClaim server-authoritative game logic.
 *
 * The phone never writes claims, scores, names or friendships directly.
 * It calls these functions, and the server validates everything first.
 *
 *   submitDrive     validates a drive, claims land, steals from rivals
 *   leaderboard     friends, national or state standings
 *   getMyInvite     returns (and creates) your invite code
 *   addFriend       adds a friend from their invite code
 *   setDisplayName  sets the name others see
 */
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const turf = require("@turf/turf");
const { validateTrail } = require("./anticheat");
const { stateForPoint } = require("./usstate");
const T = require("./territory");
const S = require("./social");

admin.initializeApp();
const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const { HttpsError } = functions.https;

const MIN_NEW_SQ_MILES = 0.02; // a loop must add at least this much new land
const MAX_FRIENDS = 100;
const BOARD_SIZE = 100;

function requireAuth(context) {
  if (!context.auth) throw new HttpsError("unauthenticated", "Sign in first.");
  return context.auth.uid;
}

// ---------------------------------------------------------------------------
// submitDrive
// ---------------------------------------------------------------------------
exports.submitDrive = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const trail = data.trail;

  // 1. Anti-cheat: shape, timing, speed, acceleration, real movement.
  const verdict = validateTrail(trail || []);
  if (!verdict.ok) throw new HttpsError("failed-precondition", verdict.reason);

  // 2. Build the loop from the route.
  const loop = T.loopFromTrail(trail);
  if (!loop) throw new HttpsError("invalid-argument", "That drive did not form a loop.");

  // 3. Load every claim. v1 scans all of them, add a geo index at scale.
  const snap = await db.collection("claims").get();
  const claims = snap.docs.map((d) => ({
    id: d.id,
    ownerId: d.get("ownerId"),
    state: d.get("state"),
    geometry: d.get("geometry"),
  }));

  // 4. Only land you do not already own counts, so re-driving a loop scores nothing.
  const ownGeometries = claims.filter((c) => c.ownerId === uid).map((c) => c.geometry);
  const newLand = T.subtractOwnLand(loop, ownGeometries);
  const newArea = newLand ? T.sqMiles(newLand) : 0;
  if (newArea < MIN_NEW_SQ_MILES) {
    throw new HttpsError("failed-precondition", "That loop does not add enough new land.");
  }

  // 5. State comes from the server, never from the phone.
  const center = turf.centroid(newLand).geometry.coordinates; // [lon, lat]
  const stateCode = stateForPoint(center[0], center[1]);

  // 6. Work out what you take from other players.
  const { stolenSqMiles, edits } = T.resolveSteals(newLand, uid, claims);

  // 7. Drive stats for the leaderboard.
  const minutes = (trail[trail.length - 1].t - trail[0].t) / 60000;
  const miles = turf.length(turf.lineString(trail.map((p) => [p.lon, p.lat])), { units: "miles" });

  // 8. Write everything at once.
  await db.runTransaction(async (tx) => {
    tx.set(db.collection("claims").doc(), {
      ownerId: uid,
      geometry: T.serialize(newLand), // a string, because Firestore rejects nested arrays
      squareMiles: newArea,
      state: stateCode,
      createdAt: FieldValue.serverTimestamp(),
    });

    const nationalDelta = { [uid]: newArea };
    const stateDelta = { [`${uid}|${stateCode}`]: newArea };
    const bump = (map, key, d) => { map[key] = (map[key] || 0) + d; };

    for (const e of edits) {
      const ref = db.collection("claims").doc(e.id);
      if (e.type === "delete") tx.delete(ref);
      else tx.update(ref, { geometry: e.geometry, squareMiles: e.squareMiles });
      bump(nationalDelta, e.ownerId, -e.lost);
      bump(stateDelta, `${e.ownerId}|${e.state || "US"}`, -e.lost);
    }

    for (const [player, delta] of Object.entries(nationalDelta)) {
      const fields = { squareMiles: FieldValue.increment(delta) };
      if (player === uid) {
        fields.minutesDriven = FieldValue.increment(minutes);
        fields.milesDriven = FieldValue.increment(miles);
        fields.homeState = stateCode;
        fields.lastDriveAt = FieldValue.serverTimestamp();
      }
      tx.set(db.collection("players").doc(player), fields, { merge: true });
    }

    for (const [key, delta] of Object.entries(stateDelta)) {
      const [player, st] = key.split("|");
      tx.set(
        db.collection("leaderboard_state").doc(`${st}_${player}`),
        { ownerId: player, state: st, squareMiles: FieldValue.increment(delta) },
        { merge: true }
      );
    }
  });

  return {
    claimedSquareMiles: newArea,
    claimedPoints: S.toPoints(newArea),
    stolenSquareMiles: stolenSqMiles,
    stolenPoints: S.toPoints(stolenSqMiles),
    minutesDriven: minutes,
    milesDriven: miles,
    state: stateCode,
  };
});

// ---------------------------------------------------------------------------
// leaderboard
// ---------------------------------------------------------------------------
async function loadPlayers(uids) {
  if (uids.length === 0) return {};
  const snaps = await db.getAll(...uids.map((u) => db.collection("players").doc(u)));
  const out = {};
  snaps.forEach((s) => { out[s.id] = s.exists ? s.data() : {}; });
  return out;
}

function toRows(entries, players) {
  return entries.map((e, i) => {
    const p = players[e.ownerId] || {};
    const sq = Math.max(0, e.squareMiles || 0); // floating point drift can dip below zero
    return {
      rank: i + 1,
      ownerId: e.ownerId,
      displayName: p.displayName || null,
      squareMiles: Math.round(sq * 1000) / 1000,
      points: S.toPoints(sq),
      minutesDriven: Math.round(p.minutesDriven || 0),
      milesDriven: Math.round((p.milesDriven || 0) * 10) / 10,
      state: e.state || p.homeState || null,
    };
  });
}

async function friendIdsOf(uid) {
  const snap = await db.collection("friendships").where("members", "array-contains", uid).get();
  const ids = new Set();
  snap.forEach((d) => (d.get("members") || []).forEach((m) => { if (m !== uid) ids.add(m); }));
  return [...ids];
}

/**
 * scope: "friends" | "national" | "state" (state also needs { state: "CO" })
 */
exports.leaderboard = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const scope = ["friends", "state"].includes(data.scope) ? data.scope : "national";

  let entries;
  if (scope === "friends") {
    const ids = [uid, ...(await friendIdsOf(uid))].slice(0, BOARD_SIZE);
    const players = await loadPlayers(ids);
    entries = ids
      .map((id) => ({ ownerId: id, squareMiles: (players[id] || {}).squareMiles || 0 }))
      .sort((a, b) => b.squareMiles - a.squareMiles);
    return { scope, rows: toRows(entries, players) };
  }

  let snap;
  if (scope === "state") {
    const st = String(data.state || "US").toUpperCase().slice(0, 2);
    snap = await db.collection("leaderboard_state")
      .where("state", "==", st).orderBy("squareMiles", "desc").limit(BOARD_SIZE).get();
    entries = snap.docs.map((d) => ({ ownerId: d.get("ownerId"), squareMiles: d.get("squareMiles"), state: st }));
  } else {
    snap = await db.collection("players").orderBy("squareMiles", "desc").limit(BOARD_SIZE).get();
    entries = snap.docs.map((d) => ({ ownerId: d.id, squareMiles: d.get("squareMiles") }));
  }
  const players = await loadPlayers(entries.map((e) => e.ownerId));
  return { scope, rows: toRows(entries, players) };
});

// ---------------------------------------------------------------------------
// Friends
// ---------------------------------------------------------------------------
exports.getMyInvite = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const privateRef = db.collection("private_players").doc(uid);
  const existing = await privateRef.get();
  if (existing.exists && existing.get("inviteCode")) return { code: existing.get("inviteCode") };

  for (let attempt = 0; attempt < 5; attempt++) {
    const code = S.generateInviteCode();
    const inviteRef = db.collection("invites").doc(code);
    try {
      await db.runTransaction(async (tx) => {
        if ((await tx.get(inviteRef)).exists) throw new Error("collision");
        tx.create(inviteRef, { uid, createdAt: FieldValue.serverTimestamp() });
        tx.set(privateRef, { inviteCode: code }, { merge: true });
      });
      return { code };
    } catch (e) {
      if (e.message !== "collision") throw e;
    }
  }
  throw new HttpsError("internal", "Could not make an invite code. Please try again.");
});

exports.addFriend = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const code = S.normalizeInviteCode(data.code);
  if (!code) throw new HttpsError("invalid-argument", "That code does not look right.");

  const invite = await db.collection("invites").doc(code).get();
  if (!invite.exists) throw new HttpsError("not-found", "No one has that code.");
  const friendUid = invite.get("uid");
  if (friendUid === uid) throw new HttpsError("failed-precondition", "That is your own code.");

  const mine = await db.collection("friendships").where("members", "array-contains", uid).count().get();
  if (mine.data().count >= MAX_FRIENDS) {
    throw new HttpsError("resource-exhausted", `You can have up to ${MAX_FRIENDS} friends.`);
  }

  const ref = db.collection("friendships").doc(S.friendshipId(uid, friendUid));
  try {
    await ref.create({ members: [uid, friendUid].sort(), createdAt: FieldValue.serverTimestamp() });
  } catch (e) {
    if (e.code !== 6) throw e; // 6 = already exists, which is fine
  }

  const friend = await db.collection("players").doc(friendUid).get();
  return { friendId: friendUid, displayName: (friend.exists && friend.get("displayName")) || "Your friend" };
});

exports.setDisplayName = functions.https.onCall(async (data, context) => {
  const uid = requireAuth(context);
  const result = S.validateDisplayName(data.name);
  if (!result.ok) throw new HttpsError("invalid-argument", result.reason);
  await db.collection("players").doc(uid).set({ displayName: result.name }, { merge: true });
  return { displayName: result.name };
});
