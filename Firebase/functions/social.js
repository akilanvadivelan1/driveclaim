/**
 * Friends, invite codes, display names and points. Pure helpers, no Firebase.
 */
const crypto = require("crypto");

// Each square mile is worth this many points.
const POINTS_PER_SQ_MILE = 100;

// No 0, O, 1 or I so codes are easy to read aloud and type.
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 8;
const CODE_PATTERN = new RegExp(`^[${ALPHABET}]{${CODE_LENGTH}}$`);

function toPoints(squareMiles) {
  return Math.round(squareMiles * POINTS_PER_SQ_MILE);
}

function generateInviteCode() {
  const bytes = crypto.randomBytes(CODE_LENGTH);
  let out = "";
  // 256 is a multiple of 32, so there is no modulo bias.
  for (let i = 0; i < CODE_LENGTH; i++) out += ALPHABET[bytes[i] % ALPHABET.length];
  return out;
}

/** Returns the clean code, or null if it does not look like one. */
function normalizeInviteCode(raw) {
  const code = String(raw || "").trim().toUpperCase();
  return CODE_PATTERN.test(code) ? code : null;
}

/** Same id no matter which friend is listed first. */
function friendshipId(a, b) {
  return [a, b].sort().join("_");
}

/** Letters, numbers, spaces, dots, dashes and underscores. 2 to 20 characters. */
function validateDisplayName(raw) {
  const name = String(raw || "").trim().replace(/\s+/g, " ");
  if (name.length < 2) return { ok: false, reason: "Names need at least 2 characters." };
  if (name.length > 20) return { ok: false, reason: "Names can be at most 20 characters." };
  if (!/^[A-Za-z0-9 ._-]+$/.test(name)) {
    return { ok: false, reason: "Use only letters, numbers, spaces, dots, dashes and underscores." };
  }
  return { ok: true, name };
}

module.exports = {
  POINTS_PER_SQ_MILE,
  toPoints,
  generateInviteCode,
  normalizeInviteCode,
  friendshipId,
  validateDisplayName,
};
