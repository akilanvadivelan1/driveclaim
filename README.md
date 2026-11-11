# Loopd

A multiplayer driving game for the U.S. Drive a loop in your car to claim the land inside it. The bigger the area (in square miles), the higher your score. Drive a loop through someone else's land and you steal the overlapping piece. They lose exactly that piece, you gain it.

## How the game works

- Tap Start drive, then drive normally.
- When your route forms a loop, the land inside becomes yours.
- If your loop overlaps a rival's territory, you capture the overlap. Their claim shrinks by that exact shape.
- Every square mile you hold is worth 1,000 points.
- Everyone's land updates live. Your land is a see-through violet, friends get their own colors, everyone else is soft gray.
- Driving a loop you already own scores nothing, so only new land counts.
- Results are spoken aloud so you never need to look at the screen.

## Why it is built this way

Scoring and stealing are server-authoritative. The phone only records the raw GPS trail and sends it up. A Firebase Cloud Function validates the drive, builds the loop, resolves overlaps, and writes the results. Firestore rules make claims and scores read-only to clients. This is what stops a player from posting a fake polygon to grab free land.

## Layout

- `Core/` is a Swift package (`TerritoryCore`) with the geometry: area, loop detection, scoring, and the steal math (polygon intersection and subtraction). Pure and unit-tested, with no UI or Firebase.
- `App/` is the SwiftUI app: GPS recording, the Apple Maps (MapKit) view, voice feedback, and the Firebase client.
- `Firebase/functions/` is the Cloud Function that owns game logic, using Turf.js for robust polygon operations.
- `Firebase/firestore.rules` locks down writes to the server.

## Accounts

Your progress (land, points, friends, name) belongs to your account, not to the phone.

- On first launch you can **create an account** with an email and password, **sign in** to an existing one, or **continue as guest**.
- A guest is upgraded in place when they create an account, so nothing they earned is lost. The player id stays the same.
- If you delete the app or get a new phone, sign in with your email and everything comes back.
- Guest progress only lives on that phone. The app says so on the sign-in screen and in the Account card (Friends screen).
- You can reset a forgotten password from the sign-in screen.
- Sign out is under Friends > Account. It is disabled while you are driving.

### Email verification and Remember me

- After you create an account, Firebase emails you a **verification link**. Tap it once and you are done. The app notices on its own and moves on.
- Verification happens **once per account**. Signing in again on any phone never asks for it again.
- The server also checks it. An email account that has not verified cannot claim land, add friends or see leaderboards.
- Guests skip verification, since they have no email.
- **Remember me** (on the sign-in screen, on by default) keeps you signed in when you close and reopen the app. If you turn it off, you sign in again with your password each time you open the app.
- Firebase sends a link rather than a numeric code. Six-digit codes need an email-sending service and a secret key, so they are not included.
- The default email comes from a Firebase address and may land in spam. You can edit the wording under Authentication > Templates in the Firebase console.

Not done yet:
- Sign in with Apple and Google. Sign in with Apple needs a paid Apple Developer membership for its capability, and the app does not need it while email is the only login option.
- **Delete my account.** Apple requires an in-app way to delete your account and data before an app that creates accounts can be released on the App Store. Plan to add this before submitting.

## Friends and leaderboards

The leaderboard has two sections, and each one can be a list or a map.

- **Friends** is a competition between you and the people you invite. The list shows points, square miles and minutes driven. The map shows only your land and your friends' land.
- **Nation** ranks everyone in the U.S. The list can switch between all of the U.S. and your state. The map shows everyone's land and you can pinch to zoom and drag around.

Points are square miles x 1,000, so 0.35 square miles is 350 points.

### How inviting works

1. Open the Friends screen (two-person icon, top left). You get an 8-character code and a Share button.
2. The shared message contains a `loopd://invite/CODE` link and the plain code.
3. If your friend already has the app, tapping the link opens it and asks "Add friend?". If they do not, they can type the code under Friends > Add a friend.
4. Friendships go both ways. Only the server can create them.

Limits to know about:
- The `loopd://` link only opens the app if it is already installed. A link that also works for people without the app (a Universal Link or App Store link) needs a website and a paid Apple Developer account, so it is not included yet.
- Display names are limited to letters, numbers, spaces, dots, dashes and underscores. There is no profanity filter yet, which you will want before a public launch because names show on the national board.
- Friends are capped at 100 per player.

## The steal rule

When your loop overlaps a victim's claim:
- Stolen area = the geometric intersection of the two polygons.
- You own the new part of your loop (empty land plus captured land). Land you already owned is not counted twice.
- The victim keeps their claim minus your loop (via polygon difference). If nothing is left, their claim is deleted.
- Scores adjust in one transaction: you gain your loop's area, each victim loses their overlap.

## Setup

### Core tests (works anywhere with Swift)

    cd Core && swift test

### Backend logic tests (works anywhere with Node)

    cd Firebase/functions && npm install && npm test

These cover anti-cheat, the state lookup, loop building, stealing, re-driving your own land, points, invite codes, name rules, and the real function handlers for sign-in, email verification and input checks. They do not talk to Firebase itself, so the first real deploy is still the true end-to-end test.

### Firebase backend

Quick path from the repo folder (any Node 22 or newer works on your Mac):

    cd Firebase/functions && npm install && cd ..
    npx -y firebase-tools@latest login
    npx -y firebase-tools@latest use --add      # pick your Firebase project
    npx -y firebase-tools@latest deploy

Using `npx` means nothing has to be installed globally, which avoids the
permission error some Macs show for `npm install -g`. If you prefer, install
once with `curl -sL https://firebase.tools | bash` and then type `firebase`
instead of the long `npx` command.

The functions run on Node 22 (2nd generation Cloud Functions). Node 20 was
shut down on Google Cloud on October 30, 2026, so do not set it back to 20.
A yellow `EBADENGINE` warning on `npm install` is harmless if your Mac has a
newer Node.

Then add `GoogleService-Info.plist` to `App/` and run `xcodegen generate`.
Until that file is in the app, Loopd skips sign-in and shows the game only, and
drives cannot be claimed.

Details:

1. Create a Firebase project. Enable Firestore, Cloud Functions, and two sign-in methods under Authentication: **Anonymous** (for guests) and **Email/Password** (for accounts) (Blaze plan is required for outbound deps).
2. `cd Firebase/functions && npm install`
3. `firebase deploy --only functions,firestore`

### iOS app (needs a Mac with Xcode 15+)

The project is set up so you do NOT build the Xcode project by hand. An
XcodeGen spec (`project.yml`) generates `Loopd.xcodeproj` with all files,
Swift packages (TerritoryCore, Firebase), the Info.plist keys and
the background capabilities already wired. The map uses Apple Maps (MapKit),
so there is no map API key to get.

Fastest path:

    cd driveclaim
    bash setup-mac.sh          # installs XcodeGen, runs tests, generates the project

Then:

1. Download `GoogleService-Info.plist` from your Firebase project into `App/`,
   then re-run `xcodegen generate` so it is included.
2. `open Loopd.xcodeproj`, pick your signing Team, choose a device, Run.

If you prefer to do it manually in Xcode instead of XcodeGen:

1. Create a new iOS App named Loopd (SwiftUI), drag in the `App/` files.
2. File > Add Package Dependencies > Add Local > `Core/` (TerritoryCore).
3. Add `https://github.com/firebase/firebase-ios-sdk` with FirebaseAuth,
   FirebaseFirestore, FirebaseFunctions, FirebaseCore.
4. Use the provided `App/Info.plist` (permissions and background modes are already in it).
5. Add `GoogleService-Info.plist`.

Note: GPS and background drive-tracking only work on a real iPhone, not the
iOS Simulator.

## Leaderboards

Two boards, both ranked by total square miles currently held:
- National: every player, across the whole country.
- State: players within one state.

The state a claim counts toward is derived on the server from the loop's centroid, so a player cannot pick a state to pad their rank. Tap the trophy icon (top-right) to open the boards and toggle between National and My State. Your row is highlighted.

Data model:
- `players/{uid}` holds a running national square-mile total.
- `leaderboard_state/{STATE_uid}` holds a running per-state total.
- Both are updated inside the same transaction as the claim, so standings never drift from the actual land.

The state leaderboard query needs a Firestore composite index on `leaderboard_state` (fields: `state` ascending, `squareMiles` descending). Firestore will prompt you with a one-click link the first time the query runs, or add it to `firestore.indexes.json`.

## Anti-cheat (`functions/anticheat.js`)

Every drive is validated on the server before any land is awarded. A drive is rejected if it:
- has too few or absurdly many GPS points, or malformed/out-of-range coordinates
- is too quick to be a real loop (under 20 seconds), has non-increasing time, or has a GPS gap over 2 minutes
- contains an impossible speed (over 120 mph) between two fixes
- contains impossible acceleration between fixes (teleport / GPS jump)
- shows almost no real movement (a stationary "drive")

All of this runs server-side. The phone cannot bypass it, and Firestore rules block clients from writing claims or scores directly. The pure logic has Node tests in `functions/test.js` (`node test.js`), and the state lookup is covered there too.

### Limits of the state lookup

`functions/usstate.js` uses coarse bounding boxes for the 50 states, with a deepest-inside tiebreak at overlaps. It is correct for inland points but can misattribute a claim right on a state border. To make it exact, swap `stateForPoint` for a reverse-geocoder (Google Geocoding `administrative_area_level_1`) or a point-in-polygon test against real state GeoJSON. Nothing else changes.

## Known limits and next steps

- The Swift `PolygonClip` uses Sutherland-Hodgman, which is exact for convex loops and approximate for concave ones. The server uses Turf.js, which handles concave shapes and holes correctly. The authoritative result is always the server's. Swapping the client to a Weiler-Atherton clip would make the local preview match exactly.
- The function scans all claims per drive. Add a geohash or tile index before you have many players.
- Next: leaderboards by city and state, daily territory decay so land must be re-defended, friends and crews, and a passenger mode with a richer UI.

## Safety

This is a driving game, so it is built to be hands-free: a big start/stop button, voice updates, and no need to look at the screen while moving. Mount your phone, start the drive before you leave, and listen for updates. Do not interact with the screen while driving, and never break traffic laws to chase points.
