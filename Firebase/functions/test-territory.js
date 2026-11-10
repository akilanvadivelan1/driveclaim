/**
 * Tests for territory.js and social.js. Run with: node test-territory.js
 */
const assert = require("assert");
const turf = require("@turf/turf");
const T = require("./territory");
const S = require("./social");

let passed = 0;
function ok(name, cond) {
  assert.ok(cond, name);
  passed++;
  console.log("  ok -", name);
}
const near = (a, b, tol) => Math.abs(a - b) <= tol;

// A square trail whose sides are `miles` long, starting at (lat0, lon0 + offsetMiles).
function squareTrail(miles, offsetMiles = 0, lat0 = 39.74, lon0 = -104.99) {
  const dLat = (miles * 1609.344) / 6371008.8 * (180 / Math.PI);
  const dLon = dLat / Math.cos((lat0 * Math.PI) / 180);
  const x = lon0 + offsetMiles * ((1609.344 / 6371008.8) * (180 / Math.PI) / Math.cos((lat0 * Math.PI) / 180));
  const corners = [[lat0, x], [lat0, x + dLon], [lat0 + dLat, x + dLon], [lat0 + dLat, x]];
  let t = 1_700_000_000_000;
  return corners.map(([lat, lon]) => ({ lat, lon, t: (t += 5000) }));
}

function claimFrom(id, ownerId, trail) {
  const loop = T.loopFromTrail(trail);
  return { id, ownerId, state: "CO", geometry: T.serialize(loop), loop };
}

console.log("Loop building:");
const one = T.loopFromTrail(squareTrail(1));
ok("a 1 mile square is about 1 square mile", near(T.sqMiles(one), 1, 0.02));
ok("stored geometry has no nested-array problem (it is a string)", typeof T.serialize(one) === "string");
ok("string round-trips back to the same area", near(T.sqMiles(T.parse(T.serialize(one))), T.sqMiles(one), 1e-6));

console.log("Figure 8 route:");
(() => {
  // Out and around one lobe, crossing, then around the other lobe.
  const base = { lat: 39.74, lon: -104.99 };
  const s = 0.01;
  const pts = [[0, 0], [s, s], [0, s], [s, 0]]; // crosses itself in the middle
  let t = 1_700_000_000_000;
  const trail = pts.map(([a, b]) => ({ lat: base.lat + a, lon: base.lon + b, t: (t += 5000) }));
  const loop = T.loopFromTrail(trail);
  ok("a self-crossing route still builds without throwing", loop !== null);
  ok("and has a positive area", loop && T.sqMiles(loop) > 0.1);
})();

console.log("Stealing:");
const victimTrail = squareTrail(1, 0);
const victim = claimFrom("v1", "alice", victimTrail);

(() => {
  const thiefLoop = T.loopFromTrail(squareTrail(1, 0.5)); // overlaps half of the victim
  const r = T.resolveSteals(thiefLoop, "bob", [victim]);
  ok("half overlap steals about 0.5 square miles", near(r.stolenSqMiles, 0.5, 0.03));
  ok("victim is shrunk, not deleted", r.edits.length === 1 && r.edits[0].type === "shrink");
  ok("victim keeps about 0.5 square miles", near(r.edits[0].squareMiles, 0.5, 0.03));
  ok("shrunk geometry is a storable string that parses", T.parse(r.edits[0].geometry) !== null);
})();

(() => {
  const thiefLoop = T.loopFromTrail(squareTrail(2, -0.5)); // fully covers the victim
  const r = T.resolveSteals(thiefLoop, "bob", [victim]);
  ok("covering a claim entirely deletes it", r.edits.length === 1 && r.edits[0].type === "delete");
  ok("and steals its full area", near(r.stolenSqMiles, 1, 0.03));
})();

(() => {
  const far = T.loopFromTrail(squareTrail(1, 0, 41.0, -100.0));
  const r = T.resolveSteals(far, "bob", [victim]);
  ok("no overlap steals nothing", r.stolenSqMiles === 0 && r.edits.length === 0);
})();

(() => {
  const mine = T.loopFromTrail(squareTrail(1, 0.5));
  const r = T.resolveSteals(mine, "alice", [victim]);
  ok("you cannot steal from yourself", r.edits.length === 0);
})();

(() => {
  const thiefLoop = T.loopFromTrail(squareTrail(1, 0.5));
  const bad = { id: "x", ownerId: "carol", state: "CO", geometry: "not json" };
  const r = T.resolveSteals(thiefLoop, "bob", [bad, victim]);
  ok("a corrupt claim is skipped and others still resolve", r.edits.length === 1);
})();

console.log("Re-driving your own land:");
(() => {
  const mine = claimFrom("m1", "bob", squareTrail(1, 0));
  const again = T.loopFromTrail(squareTrail(1, 0));
  const none = T.subtractOwnLand(again, [mine.geometry]);
  ok("driving the same loop again adds no new land", none === null || T.sqMiles(none) < 0.001);

  const half = T.loopFromTrail(squareTrail(1, 0.5));
  const added = T.subtractOwnLand(half, [mine.geometry]);
  ok("a half-overlapping loop only adds the new half", added && near(T.sqMiles(added), 0.5, 0.03));

  const fresh = T.loopFromTrail(squareTrail(1, 0, 41.0, -100.0));
  const all = T.subtractOwnLand(fresh, [mine.geometry]);
  ok("a loop elsewhere keeps all of its land", near(T.sqMiles(all), 1, 0.03));
})();

console.log("Points and friends:");
ok("1 square mile is 100 points", S.toPoints(1) === 100);
ok("0.35 square miles is 35 points", S.toPoints(0.35) === 35);
ok("invite codes are 8 valid characters", /^[A-HJ-NP-Z2-9]{8}$/.test(S.generateInviteCode()));
ok("invite codes are not all the same", new Set(Array.from({ length: 50 }, S.generateInviteCode)).size > 40);
ok("lowercase codes with spaces are cleaned", S.normalizeInviteCode(" abcd2345 ") === "ABCD2345");
ok("codes with banned characters are rejected", S.normalizeInviteCode("ABCD0O1I") === null);
ok("short codes are rejected", S.normalizeInviteCode("ABC") === null);
ok("friendship id ignores order", S.friendshipId("b", "a") === S.friendshipId("a", "b"));
ok("normal names pass", S.validateDisplayName("  Swarupa  K ").name === "Swarupa K");
ok("too short names fail", S.validateDisplayName("a").ok === false);
ok("too long names fail", S.validateDisplayName("x".repeat(21)).ok === false);
ok("symbols and markup fail", S.validateDisplayName("<script>").ok === false);

console.log(`\nAll ${passed} checks passed.`);
