# DriveClaim

A multiplayer driving game for the U.S. Drive a loop in your car to claim the land inside it. The bigger the area (in square miles), the higher your score. Drive a loop through someone else's land and you steal the overlapping piece. They lose exactly that piece, you gain it.

## How the game works

- Tap Start drive, then drive normally.
- When your route forms a loop, the land inside becomes yours.
- If your loop overlaps a rival's territory, you capture the overlap. Their claim shrinks by that exact shape.
- Your score is the total square miles you currently hold.
- Everyone's land updates live. Your land is green, rivals are red.
- Results are spoken aloud so you never need to look at the screen.

## Why it is built this way

Scoring and stealing are server-authoritative. The phone only records the raw GPS trail and sends it up. A Firebase Cloud Function validates the drive, builds the loop, resolves overlaps, and writes the results. Firestore rules make claims and scores read-only to clients. This is what stops a player from posting a fake polygon to grab free land.

## Layout

- `Core/` is a Swift package (`TerritoryCore`) with the geometry: area, loop detection, scoring, and the steal math (polygon intersection and subtraction). Pure and unit-tested, with no UI or Firebase.
- `App/` is the SwiftUI app: GPS recording, the Google Maps view, voice feedback, and the Firebase client.
- `Firebase/functions/` is the Cloud Function that owns game logic, using Turf.js for robust polygon operations.
- `Firebase/firestore.rules` locks down writes to the server.

## The steal rule

When your loop overlaps a victim's claim:
- Stolen area = the geometric intersection of the two polygons.
- You own your full loop (empty land plus captured land).
- The victim keeps their claim minus your loop (via polygon difference). If nothing is left, their claim is deleted.
- Scores adjust in one transaction: you gain your loop's area, each victim loses their overlap.

## Setup

### Core tests (works anywhere with Swift)

    cd Core && swift test

### Firebase backend

1. Create a Firebase project. Enable Firestore, Anonymous Authentication, and Cloud Functions (Blaze plan is required for outbound deps).
2. `cd Firebase/functions && npm install`
3. `firebase deploy --only functions,firestore:rules`

### iOS app (needs a Mac with Xcode 15+)

The project is set up so you do NOT build the Xcode project by hand. An
XcodeGen spec (`project.yml`) generates `DriveClaim.xcodeproj` with all files,
Swift packages (TerritoryCore, Google Maps, Firebase), the Info.plist keys and
the background capabilities already wired.

Fastest path:

    cd DriveClaim
    bash setup-mac.sh          # installs XcodeGen, runs tests, generates the project

Then, the two things only you can provide (API keys):

1. Paste your Google Maps iOS key into `App/Info.plist` (`GMSApiKey`).
2. Download `GoogleService-Info.plist` from your Firebase project into `App/`,
   then re-run `xcodegen generate` so it is included.
3. `open DriveClaim.xcodeproj`, pick your signing Team, choose a device, Run.

If you prefer to do it manually in Xcode instead of XcodeGen:

1. Create a new iOS App named DriveClaim (SwiftUI), drag in the `App/` files.
2. File > Add Package Dependencies > Add Local > `Core/` (TerritoryCore).
3. Add `https://github.com/googlemaps/ios-maps-sdk`.
4. Add `https://github.com/firebase/firebase-ios-sdk` with FirebaseAuth,
   FirebaseFirestore, FirebaseFunctions, FirebaseCore.
5. Use the provided `App/Info.plist` (keys and background modes are already in it).
6. Add `GoogleService-Info.plist` and your `GMSApiKey`.

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
