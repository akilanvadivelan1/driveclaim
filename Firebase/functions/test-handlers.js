/**
 * Runs the real Cloud Function handlers for every path that finishes BEFORE the
 * database is touched: sign-in checks, the email verification rule, and input
 * validation. No Firebase project or emulator needed. Run: node test-handlers.js
 */
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-loopd";
const assert = require("assert");
const fns = require("./index.js");

let passed = 0;
function ok(name) {
  passed++;
  console.log("  ok -", name);
}

async function codeOf(promise) {
  try {
    await promise;
    return "no error";
  } catch (e) {
    return e.code || e.message;
  }
}

const guest = { uid: "guest1", token: { firebase: { sign_in_provider: "anonymous" } } };
const unverified = { uid: "u2", token: { firebase: { sign_in_provider: "password" }, email_verified: false } };
const verified = { uid: "u3", token: { firebase: { sign_in_provider: "password" }, email_verified: true } };

const call = (name, auth, data) => fns[name].run({ auth, data, rawRequest: {} });

(async () => {
  console.log("All six functions are exported:");
  for (const n of ["submitDrive", "leaderboard", "getMyInvite", "addFriend", "setDisplayName", "deleteAccount"]) {
    assert.strictEqual(typeof fns[n].run, "function", n);
  }
  ok("submitDrive, leaderboard, getMyInvite, addFriend, setDisplayName, deleteAccount");

  console.log("Sign-in and verification checks:");
  for (const n of ["submitDrive", "leaderboard", "getMyInvite", "addFriend", "setDisplayName"]) {
    assert.strictEqual(await codeOf(call(n, null, {})), "unauthenticated", n + " signed out");
  }
  ok("every function rejects a signed-out caller");
  assert.strictEqual(await codeOf(call("deleteAccount", null, {})), "unauthenticated");
  ok("deleteAccount rejects a signed-out caller too");

  for (const n of ["submitDrive", "leaderboard", "getMyInvite", "addFriend", "setDisplayName"]) {
    assert.strictEqual(await codeOf(call(n, unverified, {})), "permission-denied", n + " unverified");
  }
  ok("every function rejects an unverified email account");

  console.log("Input validation (guests and verified accounts get past sign-in):");
  assert.strictEqual(await codeOf(call("setDisplayName", guest, { name: "a" })), "invalid-argument");
  assert.strictEqual(await codeOf(call("setDisplayName", verified, { name: "<script>" })), "invalid-argument");
  ok("bad display names are refused");

  assert.strictEqual(await codeOf(call("addFriend", guest, { code: "nope" })), "invalid-argument");
  assert.strictEqual(await codeOf(call("addFriend", verified, { code: "ABCD0O1I" })), "invalid-argument");
  ok("badly formed invite codes are refused");

  assert.strictEqual(await codeOf(call("submitDrive", guest, { trail: [] })), "failed-precondition");
  assert.strictEqual(await codeOf(call("submitDrive", guest, {})), "failed-precondition");
  const now = Date.now();
  const teleport = [
    { lat: 39.0, lon: -104.0, t: now },
    { lat: 39.0, lon: -104.0, t: now + 1000 },
    { lat: 41.0, lon: -112.0, t: now + 2000 },
    { lat: 41.0, lon: -112.0, t: now + 3000 },
    { lat: 41.0, lon: -112.0, t: now + 30000 },
  ];
  assert.strictEqual(await codeOf(call("submitDrive", guest, { trail: teleport })), "failed-precondition");
  ok("empty, missing and teleporting drives are refused before any database work");

  console.log(`\nAll ${passed} handler checks passed.`);
  process.exit(0);
})().catch((e) => {
  console.error("FAILED:", e.message);
  process.exit(1);
});
