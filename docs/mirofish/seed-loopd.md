# Loopd: seed brief

## What it is

Loopd is an iPhone game for the United States. You drive a loop in your car and the land inside the loop becomes your territory. The bigger the area in square miles, the more points you earn. If your loop crosses another player's land, you take the overlapping piece and they lose exactly that piece.

It is similar in spirit to an existing running app where players claim territory by running loops, but it is for drivers and covers the whole country.

## How the game works

- A player taps Start drive, drives a loop on real streets, and taps End drive. The route is closed with a straight line from the last point back to the first, and the enclosed area is claimed.
- Scoring is 1,000 points per square mile. A typical neighborhood loop is about 0.1 to 0.5 square miles, so it is worth 100 to 500 points. Loops under 0.02 square miles (about 20 points) do not count.
- Driving the same loop again scores nothing, because only land the player does not already own counts.
- When a new loop overlaps another player's land, the overlap moves to the driver. The previous owner's land shrinks by that exact shape and their score drops by the same amount.
- Results are read aloud, so the game can be played without looking at the screen. The app tells players to set up before driving and never touch the phone while moving.

## Social features

- Friends: a player shares an invite link or an 8 character code. Friends see each other's land on a map and compete on a friends leaderboard.
- Leaderboards: friends, the whole nation, and the player's state. Each shows points, square miles and minutes driven.
- The nation map shows everyone's land. Players can zoom and pan around the country.
- Accounts use email and password with a one time email verification. Guests can play without an account, but their progress stays on their phone.

## Rules the server enforces

- The phone only records GPS points. The server builds the loop, decides the score and resolves stealing, so players cannot post fake land.
- Anti-cheat rejects impossible speeds, teleports, long GPS gaps, drives under 20 seconds and drives with almost no movement.
- A player cannot steal from themselves.

## Current status

- A working prototype, built and tested by one developer.
- It is not on the App Store and has no public players yet.
- It has not been through Apple review.
- There is no business model yet.
- Data is stored in Firebase. The map is Apple Maps.

## Things we are unsure about

- Whether people will keep playing after the first week.
- Whether stealing creates fun rivalry or feels like harassment, especially between strangers on the national map.
- Whether chasing points makes people drive in unsafe ways, and how the public and Apple would react.
- Privacy: a player's land shape shows where they drive and live, and the national map shows it to everyone.
- Whether cheating, for example faking GPS, would spread once there are real rankings.
- Whether the game works outside dense cities, where few players overlap and land rarely gets contested.
- Whether it needs friends nearby to be fun, and how a new player with no friends in their area would feel.
