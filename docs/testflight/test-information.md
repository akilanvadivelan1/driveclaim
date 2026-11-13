# TestFlight information for Loopd

Paste these into App Store Connect. Replace anything in capitals with your own details.

## Where it goes

App Store Connect > your app > TestFlight > Test Information.

### Beta App Description

Loopd is a driving game. Drive a loop in your car and the land inside it becomes yours. Every square mile is worth 1,000 points. Invite friends, take land from each other, and compete on friends, state and national leaderboards.

This is an early test version. Please tell us what is confusing, what breaks, and what feels fun or unfair.

### Feedback Email

akilanvadivelan1@gmail.com

### What to Test

- Create an account with your email, or play as a guest.
- Drive a loop of a few city blocks and end near where you started. You should hear how many square miles and points you earned.
- Open Friends, share your invite link or code, and add a friend.
- Look at the friends and national leaderboards, and the maps.
- Tap a friend's land on the map to see whose it is.
- Try to take land from a friend by driving a loop across theirs.
- Please do not use the app while driving. Start the drive while parked, or have a passenger do it.

## Beta App Review notes

Paste this into the "Notes" box for the reviewer.

> Loopd is a territory game for drivers. The player starts a drive, drives a loop, and the area inside the loop is claimed and scored. The app uses location because the game cannot work without it.
>
> HOW TO SIGN IN: On the first screen tap "Yes, I am 13 or older". Then tap "Continue as guest". No account or password is needed. (An email account is also possible. It sends a verification link once.)
>
> LOCATION: The app asks for "While Using" access. It later asks to upgrade to "Always" so a drive keeps recording when the screen turns off, which is normal during a drive. Location is only recorded between "Start drive" and "End drive". The raw GPS points are not stored. Only the shape of the claimed land is saved.
>
> BACKGROUND MODES: "location" keeps a drive recording with the screen off. "audio" is used to read the result aloud so the driver does not have to look at the screen.
>
> DRIVING SAFETY: The app is designed to be set up before driving and used hands-free. The start screen says to set up before driving and never touch the phone while moving. Results are spoken. Nothing requires interaction while the car is moving.
>
> TESTING WITHOUT DRIVING: Claiming land needs real movement over at least about 20 seconds and a loop of a few city blocks. A short screen recording of a real drive is attached. Everything else (sign-in, maps, friends, leaderboards, account deletion) can be checked without driving.
>
> AGE: The first screen asks if the user is 13 or older. Under 13 is blocked.
>
> ACCOUNT DELETION: Friends screen > Account > Delete account.

Attach a screen recording of a real drive, ending with the "You claimed ..." message, if App Store Connect lets you add an attachment to the review notes.

## Public link for friends

1. TestFlight > External Testing > the plus button > create a group called Friends.
2. Add your build to the group and submit it for Beta App Review. The first build of each version is reviewed before testers can install it, which often takes a day or so.
3. In the group, turn on Public Link and set a tester limit, for example 100 to start. Anyone with the link can join until the limit is reached, so do not post it somewhere you cannot take it back from. You can switch it off at any time.
4. Share the link. Testers install Apple's TestFlight app first, then open your link.

Builds expire after 90 days, so upload a new one before then.

## App Privacy answers (needed for the App Store, useful now)

In App Store Connect > App Privacy. These match what the app does today. Re-check them if the app changes.

| Data type | Collected | Linked to the person | Used for tracking | Purpose |
| --- | --- | --- | --- | --- |
| Email address | Yes, if they make an account | Yes | No | App functionality |
| Name (display name) | Yes | Yes | No | App functionality |
| Precise location | Yes, during a drive | Yes | No | App functionality |
| User ID | Yes | Yes | No | App functionality |
| Other user content (land shapes, points, friends) | Yes | Yes | No | App functionality |

There is no advertising, no analytics and no tracking. Do not tick "used for tracking".

## Export compliance

The app uses only standard HTTPS provided by iOS. When App Store Connect asks about encryption, that normally means "no non-exempt encryption". This is a legal declaration that you make yourself, so read Apple's wording before you answer.

## Before you share the link widely

- Names have no profanity filter, and they show on the national leaderboard to strangers.
- There is no way to report or block another player. Apple's rules for apps with user-created content (guideline 1.2) usually expect that for a public release.
- The national map shows everyone's land to everyone, which can reveal where people live. The privacy policy says so, but you may want to limit the map to friends before a public launch.
