/**
 * Deletes everything stored about one player. The database is passed in so this can be
 * tested with a small fake, with no Firebase project needed.
 *
 * What goes:
 *   claims they own, their leaderboard rows, every friendship they are part of,
 *   their invite codes, their private record and their public player record.
 *
 * What stays: other players' own land and scores. Land the player had taken from someone
 * is not given back, it simply becomes unclaimed.
 */
async function deletePlayerData(db, uid) {
  const writer = db.bulkWriter();
  const pending = [];
  const deleted = { claims: 0, leaderboardRows: 0, friendships: 0, inviteCodes: 0 };

  const remove = (ref) => pending.push(writer.delete(ref));

  const claims = await db.collection("claims").where("ownerId", "==", uid).get();
  claims.forEach((d) => { remove(d.ref); deleted.claims++; });

  const rows = await db.collection("leaderboard_state").where("ownerId", "==", uid).get();
  rows.forEach((d) => { remove(d.ref); deleted.leaderboardRows++; });

  const friendships = await db.collection("friendships").where("members", "array-contains", uid).get();
  friendships.forEach((d) => { remove(d.ref); deleted.friendships++; });

  // Query by owner instead of reading private_players, in case two codes were ever made.
  const invites = await db.collection("invites").where("uid", "==", uid).get();
  invites.forEach((d) => { remove(d.ref); deleted.inviteCodes++; });

  remove(db.collection("private_players").doc(uid));
  remove(db.collection("players").doc(uid));

  await writer.close();
  await Promise.all(pending);
  return deleted;
}

module.exports = { deletePlayerData };
