/**
 * Lightweight sanity tests for the pure logic (anti-cheat + state lookup).
 * Run with: node test.js  (no Firebase emulator needed).
 */
const assert = require("assert");
const { validateTrail } = require("./anticheat");
const { stateForPoint } = require("./usstate");

let passed = 0;
function ok(name, cond) {
  assert.ok(cond, name);
  passed++;
  console.log("  ok -", name);
}

// Build a realistic ~0.3 mile square loop near Denver over ~60 seconds.
function realLoop() {
  const base = { lat: 39.74, lon: -104.99, t: Date.now() };
  const s = 0.004;
  const corners = [
    [0, 0], [0, s], [s, s], [s, 0], [0, 0],
  ];
  // interpolate a few points per edge so speeds are sane
  const pts = [];
  let t = base.t;
  for (let c = 0; c < corners.length - 1; c++) {
    const [aLat, aLon] = corners[c];
    const [bLat, bLon] = corners[c + 1];
    for (let k = 0; k < 5; k++) {
      const f = k / 5;
      pts.push({
        lat: base.lat + aLat + (bLat - aLat) * f,
        lon: base.lon + aLon + (bLon - aLon) * f,
        t: (t += 3000), // 3s between points
      });
    }
  }
  return pts;
}

console.log("Anti-cheat:");
ok("accepts a realistic loop", validateTrail(realLoop()).ok === true);

ok("rejects too few points", validateTrail([{ lat: 1, lon: 1, t: 0 }]).ok === false);

ok("rejects teleport / impossible speed", (() => {
  const now = Date.now();
  const trail = [
    { lat: 39.0, lon: -104.0, t: now },
    { lat: 39.0, lon: -104.0, t: now + 1000 },
    { lat: 41.0, lon: -112.0, t: now + 2000 }, // hundreds of miles in 1s
    { lat: 41.0, lon: -112.0, t: now + 3000 },
    { lat: 41.0, lon: -112.0, t: now + 4000 },
  ];
  return validateTrail(trail).ok === false;
})());

ok("rejects backwards time", (() => {
  const now = Date.now();
  const t = realLoop();
  t[3].t = now - 999999;
  return validateTrail(t).ok === false;
})());

ok("rejects a stationary 'drive' (no movement)", (() => {
  const now = Date.now();
  const trail = [];
  for (let i = 0; i < 10; i++) trail.push({ lat: 39.74, lon: -104.99, t: now + i * 5000 });
  return validateTrail(trail).ok === false;
})());

console.log("State lookup:");
ok("Denver -> CO", stateForPoint(-104.99, 39.74) === "CO");
ok("Los Angeles -> CA", stateForPoint(-118.24, 34.05) === "CA");
ok("Austin -> TX", stateForPoint(-97.74, 30.27) === "TX");
ok("Manhattan -> NY", stateForPoint(-73.97, 40.78) === "NY");
ok("mid-ocean -> US fallback", stateForPoint(-40.0, 30.0) === "US");

console.log(`\nAll ${passed} checks passed.`);
