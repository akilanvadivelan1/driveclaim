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

### The map

- **Opening screen:** Loopd asks for location as soon as the home screen shows, then zooms to you (about 3 miles across). The arrow button, bottom right, flies back to you any time, including after you have panned away.
- **Colors:** your land is yellow, each friend gets their own color (cyan, orange, blue or lime), and everyone else is grey. The key on the leaderboard map shows this.
- **Tap to see whose land it is:** tap any of your own or a friend's land, on the home screen or on the Friends map. A card shows the name, how much land is under your finger, and the friend's total points. Tapping a stranger's land shows nothing, so strangers' names are only ever shown on the leaderboard.
- **If location is off:** a bar on the home screen says so, with a button to open Settings.

### App icon and logo

The app icon and the logo on the first screens come from one image. Until you add it, the app uses a plain "Loopd" name and the default icon, and it builds and runs as normal.

To add it, on a Mac, with the logo saved as a file:

    bash scripts/add-logo.sh ~/Downloads/loopd-logo.png
    xcodegen generate && open Loopd.xcodeproj

The logo must be square. The script turns it into the 1024 x 1024 PNG with no transparency that Apple requires, and puts it in `App/Assets.xcassets` twice: once as `AppIcon` and once as `LogoMark` for the screens. Do not round the corners yourself, because iOS does that.

The accent yellow in `App/Theme.swift` (`Theme.accent`) is a bright road-paint yellow. The logo's yellow is a darker mustard. To make them match, replace the hex in `Theme.accent` and `Theme.mineUI` with the logo's exact color.

### Age check

The first time the app opens, before sign-in, it asks "Are you 13 or older?". Both answers look the same, so neither one is pushed.

- Yes lets you continue to sign in or play as a guest.
- No ends it. The app shows a short message and never asks again on that phone, so the answer cannot be changed by trying again. If a guest or account was already on the phone, it is signed out.
- The answer is stored on the phone only. Deleting and reinstalling the app asks again, and the server does not check it. A reinstall-proof, server-checked age gate would need more work.
- This is a basic gate and not legal advice. Before a public launch, get a privacy policy and have a lawyer look at the rules for children's data (COPPA in the U.S.), because the game collects location.

### Deleting an account

Friends > Account > Delete account. After a confirmation it removes the player's land, points, leaderboard rows, friend links, invite codes and name, and then their sign-in. It works for guests and for email accounts, and it does not need a verified email. It is blocked while a drive is in progress.

For the server to remove the sign-in itself, its service account needs the Firebase Authentication Admin role. If it does not have it, the data is still deleted and the app removes the sign-in from the phone instead. To grant the role, run this once in Cloud Shell:

    gcloud projects add-iam-policy-binding loopd-e2ba1 --member=serviceAccount:792316187993-compute@developer.gserviceaccount.com --role=roles/firebaseauth.admin

### The website

The site lives in `Firebase/hosting` and is published to `https://loopd-e2ba1.web.app`. It has a home page, the privacy policy (`/privacy`) and a not-found page. It follows the same look as the app: night asphalt, with yellow meaning you.

- **No gradients, glows, scripts or inline styles.** The site's security headers (in `Firebase/firebase.json`) block scripts and inline styles, so the checker below fails if one slips in.
- **The example map tells the truth.** It shows a loop of 30 blocks (an eighth of a mile each), which is 0.47 square miles and 469 points, with 6 blocks taken from a friend. `scripts/check-site.py` works those numbers out from the drawing and from the server's real scoring rate, and fails if the page disagrees.
- **Check it any time:** `python3 scripts/check-site.py`
- **Publish it:**

        bash scripts/add-logo.sh ~/Downloads/YOUR-LOGO-FILE   # also makes the site's logo, tab icon and home-screen icon
        bash scripts/check-before-publish.sh
        cd Firebase && npx -y firebase-tools@latest deploy --only hosting

- **When your TestFlight public link exists,** swap the "Ask for a beta invite" button for it. Use your real link in place of the made-up one below:

        sed -i '' 's#mailto:akilanvadivelan1@gmail.com?subject=Loopd%20beta%20invite#https://testflight.apple.com/join/YOUR_REAL_CODE#; s#Ask for a beta invite#Join the beta on TestFlight#' Firebase/hosting/index.html

- **Preview on your Mac:** `cd Firebase/hosting && python3 -m http.server 8000`, then open `http://localhost:8000`. The privacy page is at `/privacy.html` there, because the local server does not have the clean-URL setting.

### Business model

Loopd is free. There is no paywall, subscription or advertising. Paid-upfront apps get very few downloads, and this game needs friends to join. Extras such as cosmetics or stats could come later, but never points, land or privacy.

### Shipping to TestFlight

Follow `docs/testflight/ship-it.md`. Two helper scripts:

    bash scripts/set-team.sh               # saves your Apple Team ID so Xcode stops forgetting it
    bash scripts/preflight-testflight.sh   # checks the icon, bundle ID, Firebase file, location text and privacy manifest

The app includes `App/PrivacyInfo.xcprivacy`, which Apple requires. It declares the one system feature the app uses that needs a reason (saved settings) and the data the app collects.

### Going public

1. Fill in your details and publish the privacy page (see `docs/testflight/test-information.md` for the whole checklist):

        bash scripts/check-before-publish.sh
        cd Firebase && npx -y firebase-tools@latest deploy --only hosting

   The privacy page is then at `https://loopd-e2ba1.web.app/privacy`. Use that address as the Privacy Policy URL in App Store Connect, and `https://loopd-e2ba1.web.app` as the Support URL.
2. Deploy the new `deleteAccount` function (`npx -y firebase-tools@latest deploy --only functions`). A new function may need the public-access step from earlier, run in Cloud Shell:

        gcloud run services add-iam-policy-binding deleteaccount --region=us-central1 --member=allUsers --role=roles/run.invoker --project=loopd-e2ba1
3. Upload a build, create an External group in TestFlight and turn on its public link.

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
- is too quick to be a real loop (under 20 seconds), has non-increasing time, or has a GPS gap over 5 minutes
- averages over 120 mph across any stretch of 5 seconds or more, or contains a single jump that implies over 300 mph (a teleport)
- shows almost no real movement (a stationary "drive")

All of this runs server-side. The phone cannot bypass it, and Firestore rules block clients from writing claims or scores directly. The pure logic has Node tests in `functions/test.js` (`node test.js`), and the state lookup is covered there too.

### Why speed is measured over 5 seconds

Real GPS wobbles by several meters from one reading to the next. Over a single second that wobble can look like a 30 to 80 mph change in speed, so judging each hop would reject honest drivers. The server compares each reading with the one at least 5 seconds earlier, where the wobble is small next to the distance covered. The tests in `test.js` use noisy simulated drives to prove honest drives pass and teleports, stale locations and 200 mph drives do not.

The app also cleans the data before sending it. It skips readings with a weak signal (over 30 m of error), the old cached location iPhones return first, and jumps no car could make, and it thins out tiny movements while parked.

### Limits of the state lookup

`functions/usstate.js` uses coarse bounding boxes for the 50 states, with a deepest-inside tiebreak at overlaps. It is correct for inland points but can misattribute a claim right on a state border. To make it exact, swap `stateForPoint` for a reverse-geocoder (Google Geocoding `administrative_area_level_1`) or a point-in-polygon test against real state GeoJSON. Nothing else changes.

## Known limits and next steps

- The Swift `PolygonClip` uses Sutherland-Hodgman, which is exact for convex loops and approximate for concave ones. The server uses Turf.js, which handles concave shapes and holes correctly. The authoritative result is always the server's. Swapping the client to a Weiler-Atherton clip would make the local preview match exactly.
- The function scans all claims per drive. Add a geohash or tile index before you have many players.
- Next: leaderboards by city and state, daily territory decay so land must be re-defended, friends and crews, and a passenger mode with a richer UI.

## Safety

This is a driving game, so it is built to be hands-free: a big start/stop button, voice updates, and no need to look at the screen while moving. Mount your phone, start the drive before you leave, and listen for updates. Do not interact with the screen while driving, and never break traffic laws to chase points.
