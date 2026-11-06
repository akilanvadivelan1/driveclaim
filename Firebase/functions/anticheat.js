/**
 * Server-side anti-cheat for DriveClaim.
 *
 * Every check runs on the trail the phone uploads, before any land is awarded.
 * A drive must pass all checks. Each returns { ok: false, reason } on failure.
 */
const turf = require("@turf/turf");

const MAX_SPEED_MPH = 120;        // highway realistic ceiling
const MAX_ACCEL_MPH_PER_S = 15;   // ~0-60 in 4s; beyond this is teleport/jitter
const MIN_POINTS = 4;
const MAX_POINTS = 50000;         // guards against payload-bomb claims
const MIN_DRIVE_SECONDS = 20;     // a real loop takes time
const MAX_GAP_SECONDS = 120;      // long GPS gap = we can't trust the path between
const MIN_AVG_SPEED_MPH = 3;      // below walking pace over the whole drive = not a car

function speedMphBetween(a, b) {
  const meters = turf.distance(
    turf.point([a.lon, a.lat]),
    turf.point([b.lon, b.lat]),
    { units: "meters" }
  );
  const dtHours = Math.max((b.t - a.t) / 3600000, 1 / 3600);
  return meters / 1609.344 / dtHours;
}

function checkShape(trail) {
  if (!Array.isArray(trail)) return { ok: false, reason: "No trail." };
  if (trail.length < MIN_POINTS) return { ok: false, reason: "Drive too short." };
  if (trail.length > MAX_POINTS) return { ok: false, reason: "Trail too large." };
  for (const p of trail) {
    if (typeof p.lat !== "number" || typeof p.lon !== "number" || typeof p.t !== "number") {
      return { ok: false, reason: "Malformed GPS point." };
    }
    if (p.lat < -90 || p.lat > 90 || p.lon < -180 || p.lon > 180) {
      return { ok: false, reason: "GPS point out of range." };
    }
  }
  return { ok: true };
}

function checkTiming(trail) {
  const first = trail[0].t;
  const last = trail[trail.length - 1].t;
  if (last <= first) return { ok: false, reason: "Timestamps not increasing." };
  if ((last - first) / 1000 < MIN_DRIVE_SECONDS) {
    return { ok: false, reason: "Drive too quick to be real." };
  }
  for (let i = 1; i < trail.length; i++) {
    const gap = (trail[i].t - trail[i - 1].t) / 1000;
    if (gap < 0) return { ok: false, reason: "Time ran backwards." };
    if (gap > MAX_GAP_SECONDS) return { ok: false, reason: "GPS signal gap too long." };
  }
  return { ok: true };
}

function checkSpeedAndAccel(trail) {
  let prevSpeed = null;
  for (let i = 1; i < trail.length; i++) {
    const a = trail[i - 1];
    const b = trail[i];
    const mph = speedMphBetween(a, b);
    if (mph > MAX_SPEED_MPH) {
      return { ok: false, reason: "Impossible speed detected." };
    }
    if (prevSpeed !== null) {
      const dtSec = Math.max((b.t - a.t) / 1000, 1);
      const accel = Math.abs(mph - prevSpeed) / dtSec;
      if (accel > MAX_ACCEL_MPH_PER_S) {
        return { ok: false, reason: "Impossible acceleration (teleport)." };
      }
    }
    prevSpeed = mph;
  }
  return { ok: true };
}

// A car drive covers real ground. A loop of near-zero length that still
// encloses area (e.g. two far points reported as "adjacent") is suspicious.
function checkMovement(trail) {
  const line = turf.lineString(trail.map((p) => [p.lon, p.lat]));
  const lengthMeters = turf.length(line, { units: "meters" });
  const seconds = (trail[trail.length - 1].t - trail[0].t) / 1000;
  const avgMph = lengthMeters / 1609.344 / (seconds / 3600);
  if (avgMph < MIN_AVG_SPEED_MPH) {
    return { ok: false, reason: "Not enough movement for a drive." };
  }
  return { ok: true };
}

/** Run every check. Returns { ok: true } or { ok: false, reason }. */
function validateTrail(trail) {
  for (const check of [checkShape, checkTiming, checkSpeedAndAccel, checkMovement]) {
    const r = check(trail);
    if (!r.ok) return r;
  }
  return { ok: true };
}

module.exports = { validateTrail, speedMphBetween, MAX_SPEED_MPH };
