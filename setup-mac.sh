#!/usr/bin/env bash
# One-shot setup for building DriveClaim on a Mac.
# Run from the DriveClaim folder:  bash setup-mac.sh
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

echo "==> Generating DriveClaim.xcodeproj from project.yml..."
xcodegen generate

echo ""
echo "Done. Next steps (these need YOUR keys and cannot be scripted):"
echo "  1. Put your Google Maps iOS key into App/Info.plist (GMSApiKey)."
echo "  2. Download GoogleService-Info.plist from your Firebase project"
echo "     and drop it into the App/ folder, then re-run: xcodegen generate"
echo "  3. open DriveClaim.xcodeproj"
echo "  4. Pick your Team under Signing & Capabilities, choose a device, and Run."
echo ""
echo "GPS and background drive-tracking only work on a REAL iPhone, not the simulator."
