#!/usr/bin/env bash
# One-shot setup for building Loopd on a Mac.
# Run from the repo folder:  bash setup-mac.sh
set -euo pipefail

echo "==> Checking for Xcode..."
if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode is not installed. Install it from the Mac App Store, then re-run."
  exit 1
fi

echo "==> Checking for Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install it from https://brew.sh then re-run."
  exit 1
fi

echo "==> Installing XcodeGen (generates the .xcodeproj for you)..."
brew list xcodegen >/dev/null 2>&1 || brew install xcodegen

echo "==> Running core Swift tests (pure game logic)..."
( cd Core && swift test )

echo "==> Generating Loopd.xcodeproj from project.yml..."
rm -rf DriveClaim.xcodeproj   # leftover from before the rename
xcodegen generate

echo ""
echo "Done. Next steps:"
echo "  1. Download GoogleService-Info.plist from your Firebase project"
echo "     and drop it into the App/ folder, then re-run: xcodegen generate"
echo "  2. open Loopd.xcodeproj"
echo "  3. Pick your Team under Signing & Capabilities, choose a device, and Run."
echo "  (The map uses Apple Maps, so there is no map API key to set up.)"
echo ""
echo "GPS and background drive-tracking only work on a REAL iPhone, not the simulator."
