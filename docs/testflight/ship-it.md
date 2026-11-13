# Shipping Loopd to TestFlight

Loopd is free. There is no paywall, no subscription and no ads.

## 1. Deploy the backend first

The app calls these, so they have to be live before testers use it.

    cd ~/driveclaim && git pull
    cd Firebase/functions && npm install && cd ..
    npx -y firebase-tools@latest deploy --only functions,hosting

In Cloud Shell (console.cloud.google.com, Loopd project, the terminal icon at the top right), make the new function public and let it delete sign-ins:

    gcloud run services add-iam-policy-binding deleteaccount --region=us-central1 --member=allUsers --role=roles/run.invoker --project=loopd-e2ba1
    gcloud projects add-iam-policy-binding loopd-e2ba1 --member=serviceAccount:792316187993-compute@developer.gserviceaccount.com --role=roles/firebaseauth.admin

Fill in the privacy page first (see `scripts/check-before-publish.sh`).

## 2. Check the project

    xcodegen generate && open Loopd.xcodeproj

Pick your Team in Signing & Capabilities, then save it so it stops resetting:

    bash scripts/set-team.sh
    bash scripts/preflight-testflight.sh

Fix every FAIL it lists. A WARN about the privacy page matters for external testing.

## 3. Create the app in App Store Connect

appstoreconnect.apple.com > Apps > plus > New App. Platform iOS, any SKU, your bundle ID, and a name. If "Loopd" is taken on the App Store, pick a variation. The name shown on the phone can stay Loopd.

## 4. Archive and upload

1. Free up at least 10 GB.
2. In Xcode, set the run destination to "Any iOS Device (arm64)".
3. Product > Archive.
4. In the Organizer window that opens, choose Distribute App > TestFlight & App Store (or App Store Connect) > Distribute, and keep automatic signing.
5. When asked about encryption, read Apple's wording and answer for yourself. Loopd only uses the standard secure connections built into iOS.

Every upload needs a higher build number than the last. Edit CURRENT_PROJECT_VERSION in project.yml, then run xcodegen generate and set your Team again if you have not saved it.

## 5. Test it yourself

After 10 to 30 minutes the build appears in App Store Connect > TestFlight. You are already an internal tester. Install Apple's TestFlight app on your iPhone, sign in with that Apple ID, and install Loopd.

## 6. Friends and the public link

Follow "Public link for friends" in `test-information.md`. You need the privacy page live and the Test Information filled in. The first build of each version goes through Beta App Review.

## If an upload is refused

The email from Apple names the problem. Common ones:
- Icon with transparency or the wrong size: run the preflight check.
- Missing location text: the preflight check covers it.
- Build number already used: raise it.
- A missing agreement: App Store Connect > Business shows anything you still have to accept.
