/**
 * Tests account deletion against a small in-memory stand-in for Firestore.
 * Run with: node test-account.js
 */
const assert = require("assert");
const { deletePlayerData } = require("./account");

let passed = 0;
function ok(name, cond) {
  assert.ok(cond, name);
  passed++;
  console.log("  ok -", name);
}

// A tiny fake of the parts of Firestore the deletion code uses.
function fakeDb(seed) {
  const data = {};
  for (const [name, docs] of Object.entries(seed)) data[name] = new Map(Object.entries(docs));

  const makeRef = (name, id) => ({
    name, id,
    get: async () => {
      const exists = data[name] && data[name].has(id);
      return { exists: !!exists, get: (f) => (exists ? data[name].get(id)[f] : undefined) };
    },
  });
  const makeSnap = (name, entries) => ({
    size: entries.length,
    forEach: (cb) => entries.forEach(([id, value]) => cb({ id, ref: makeRef(name, id), get: (f) => value[f] })),
  });

  return {
    data,
    collection: (name) => ({
      doc: (id) => makeRef(name, id),
      where: (field, op, value) => ({
        get: async () => {
          const rows = [...(data[name] || new Map()).entries()].filter(([, v]) => {
            if (op === "==") return v[field] === value;
            if (op === "array-contains") return Array.isArray(v[field]) && v[field].includes(value);
            throw new Error("unsupported operator " + op);
          });
          return makeSnap(name, rows);
        },
      }),
    }),
    bulkWriter: () => ({
      delete: async (ref) => { if (data[ref.name]) data[ref.name].delete(ref.id); },
      close: async () => {},
    }),
  };
}

const seed = () => ({
  claims: {
    c1: { ownerId: "alice" }, c2: { ownerId: "alice" }, c3: { ownerId: "bob" },
  },
  leaderboard_state: {
    CO_alice: { ownerId: "alice", state: "CO" }, CO_bob: { ownerId: "bob", state: "CO" },
  },
  friendships: {
    alice_bob: { members: ["alice", "bob"] },
    alice_carol: { members: ["alice", "carol"] },
    bob_carol: { members: ["bob", "carol"] },
  },
  invites: {
    AAAA2222: { uid: "alice" }, BBBB3333: { uid: "bob" }, CCCC4444: { uid: "alice" }, // alice has two codes
  },
  private_players: { alice: { inviteCode: "AAAA2222" }, bob: { inviteCode: "BBBB3333" } },
  players: { alice: { displayName: "Alice" }, bob: { displayName: "Bob" } },
});

(async () => {
  console.log("Deleting one player:");
  const db = fakeDb(seed());
  const result = await deletePlayerData(db, "alice");

  ok("their claims are gone", !db.data.claims.has("c1") && !db.data.claims.has("c2"));
  ok("other players' claims stay", db.data.claims.has("c3"));
  ok("their leaderboard row is gone", !db.data.leaderboard_state.has("CO_alice"));
  ok("other players' leaderboard rows stay", db.data.leaderboard_state.has("CO_bob"));
  ok("every friendship they were in is gone", !db.data.friendships.has("alice_bob") && !db.data.friendships.has("alice_carol"));
  ok("friendships between other people stay", db.data.friendships.has("bob_carol"));
  ok("all of their invite codes are gone, even a second one", !db.data.invites.has("AAAA2222") && !db.data.invites.has("CCCC4444"));
  ok("other players' invite codes stay", db.data.invites.has("BBBB3333"));
  ok("their private and public records are gone", !db.data.private_players.has("alice") && !db.data.players.has("alice"));
  ok("other players' records stay", db.data.private_players.has("bob") && db.data.players.has("bob"));
  ok("it reports what it removed", result.claims === 2 && result.leaderboardRows === 1 && result.friendships === 2 && result.inviteCodes === 2);

  console.log("Edge cases:");
  const again = await deletePlayerData(db, "alice");
  ok("deleting twice is harmless and finds nothing", again.claims === 0 && again.friendships === 0 && again.inviteCodes === 0);

  const db2 = fakeDb(seed());
  await deletePlayerData(db2, "nobody");
  ok("deleting someone who never existed changes nothing", db2.data.claims.size === 3 && db2.data.players.size === 2);

  const db3 = fakeDb({ players: { guest1: { squareMiles: 0 } } });
  const r3 = await deletePlayerData(db3, "guest1");
  ok("a guest with only a player record is deleted cleanly", !db3.data.players.has("guest1") && r3.claims === 0);

  console.log(`\nAll ${passed} checks passed.`);
  process.exit(0);
})().catch((e) => { console.error("FAILED:", e.message); process.exit(1); });
