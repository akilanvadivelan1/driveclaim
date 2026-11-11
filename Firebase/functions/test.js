/**
 * Tests for the anti-cheat rules and the state lookup, using GPS data that wobbles
 * the way a real phone does. Run with: node test.js  (no Firebase needed).
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

// Repeatable random numbers so a failure can always be reproduced.
function rng(seed) {
  let s = seed >>> 0;
  return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296);
}
function gaussian(rand) {
  const u = Math.max(rand(), 1e-12), v = rand();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

const LAT0 = 39.74, LON0 = -104.99;
const M_PER_DEG_LAT = 111320;
const mPerDegLon = M_PER_DEG_LAT * Math.cos((LAT0 * Math.PI) / 180);

/**
 * A car driving a square loop, one GPS reading per second.
 * sideMeters: size of the square. mph: steady speed. noiseMeters: GPS wobble (std dev).
 */
function drive({ sideMeters = 800, mph = 30, noiseMeters = 0, seed = 1, t0 = 1_700_000_000_000 } = {}) {
  const rand = rng(seed);
  const mps = mph * 0.44704;
  const corners = [[0, 0], [0, sideMeters], [sideMeters, sideMeters], [sideMeters, 0], [0, 0]]; // [north, east]
  const pts = [];
  let t = t0;
  for (let c = 0; c < corners.length - 1; c++) {
    const [n1, e1] = corners[c], [n2, e2] = corners[c + 1];
    const steps = Math.max(1, Math.round(sideMeters / mps));
    for (let k = 0; k < steps; k++) {
      const f = k / steps;
      const n = n1 + (n2 - n1) * f + gaussian(rand) * noiseMeters;
      const e = e1 + (e2 - e1) * f + gaussian(rand) * noiseMeters;
      pts.push({ lat: LAT0 + n / M_PER_DEG_LAT, lon: LON0 + e / mPerDegLon, t });
      t += 1000;
    }
  }
  return pts;
}

console.log("Honest drives pass, even with real-world GPS wobble:");
ok("a clean 30 mph loop", validateTrail(drive()).ok);
ok("a 30 mph loop with 5 m of GPS wobble", validateTrail(drive({ noiseMeters: 5 })).ok);
ok("a 45 mph loop with 10 m of wobble", validateTrail(drive({ mph: 45, noiseMeters: 10, seed: 7 })).ok);
ok("a 25 mph loop with 15 m of wobble (a poor signal)", validateTrail(drive({ mph: 25, noiseMeters: 15, seed: 3 })).ok);
ok("a 65 mph highway loop with 8 m of wobble", validateTrail(drive({ sideMeters: 3000, mph: 65, noiseMeters: 8, seed: 11 })).ok);

// Proves the fix: the OLD rule judged every one-second hop and flagged speed
// changes above 15 mph per second. Measure how often that rule would have fired.
(() => {
  const trail = drive({ mph: 30, noiseMeters: 8, seed: 5 });
  const { speedMphBetween } = require("./anticheat");
  let worst = 0, prev = null;
  for (let i = 1; i < trail.length; i++) {
    const v = speedMphBetween(trail[i - 1], trail[i]);
    if (prev !== null) worst = Math.max(worst, Math.abs(v - prev));
    prev = v;
  }
  ok(`the old per-second rule would have rejected this honest drive (worst jump ${worst.toFixed(0)} mph in 1 s)`, worst > 15);
  ok("and the new rule accepts it", validateTrail(trail).ok);
})();

console.log("Stop and go:");
(() => {
  const trail = drive({ noiseMeters: 4, seed: 9 });
  const half = Math.floor(trail.length / 2);
  // Sit at a red light for 90 seconds in the middle (readings keep coming, car does not move).
  const stopped = [];
  for (let k = 0; k < 90; k++) {
    stopped.push({ lat: trail[half].lat + (k % 3) * 1e-6, lon: trail[half].lon, t: trail[half].t + (k + 1) * 1000 });
  }
  const shift = 91 * 1000;
  const after = trail.slice(half + 1).map((p) => ({ ...p, t: p.t + shift }));
  ok("a 90 second stop at a light", validateTrail([...trail.slice(0, half + 1), ...stopped, ...after]).ok);
})();

console.log("Cheating and bad data are still rejected:");
(() => {
  const t = drive({ noiseMeters: 3, seed: 2 });
  const mid = Math.floor(t.length / 2);
  const jumped = t.map((p, i) => (i >= mid ? { ...p, lat: p.lat + 0.5 } : p)); // 55 km in one second
  const r = validateTrail(jumped);
  ok("a teleport in the middle of a drive", r.ok === false && /speed/i.test(r.reason));
})();
(() => {
  const t = drive({ noiseMeters: 3, seed: 2 });
  const jumped = t.map((p, i) => (i === t.length - 1 ? { ...p, lat: p.lat + 0.5 } : p));
  ok("a teleport in the very last second", validateTrail(jumped).ok === false);
})();
(() => {
  // The phone hands over an old cached location first, miles from where the drive really starts.
  const t = drive({ noiseMeters: 3, seed: 2 });
  const stale = [{ lat: LAT0 + 0.2, lon: LON0 - 0.2, t: t[0].t - 1000 }, ...t];
  ok("a stale cached first reading far away", validateTrail(stale).ok === false);
})();
ok("a sustained 200 mph drive", validateTrail(drive({ sideMeters: 6000, mph: 200, seed: 4 })).ok === false);
ok("too few points", validateTrail([{ lat: 1, lon: 1, t: 0 }]).ok === false);
ok("time running backwards", (() => {
  const t = drive();
  t[10].t = t[0].t - 5000;
  return validateTrail(t).ok === false;
})());
ok("a stationary 'drive' with no movement", (() => {
  const t = [];
  for (let i = 0; i < 40; i++) t.push({ lat: LAT0, lon: LON0, t: 1_700_000_000_000 + i * 5000 });
  return validateTrail(t).ok === false;
})());
ok("a signal gap of 10 minutes", (() => {
  const t = drive();
  return validateTrail([...t.slice(0, 30), ...t.slice(30).map((p) => ({ ...p, t: p.t + 600_000 }))]).ok === false;
})());
ok("a signal gap of 3 minutes is allowed", (() => {
  const t = drive();
  return validateTrail([...t.slice(0, 30), ...t.slice(30).map((p) => ({ ...p, t: p.t + 180_000 }))]).ok === true;
})());

console.log("State lookup:");
ok("Denver -> CO", stateForPoint(-104.99, 39.74) === "CO");
ok("Los Angeles -> CA", stateForPoint(-118.24, 34.05) === "CA");
ok("Austin -> TX", stateForPoint(-97.74, 30.27) === "TX");
ok("Manhattan -> NY", stateForPoint(-73.97, 40.78) === "NY");
ok("Seattle area -> WA", stateForPoint(-122.2, 47.4) === "WA");
ok("mid-ocean -> US fallback", stateForPoint(-40.0, 30.0) === "US");

console.log(`\nAll ${passed} checks passed.`);
