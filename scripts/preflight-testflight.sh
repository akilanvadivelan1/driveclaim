#!/usr/bin/env bash
# Checks the things that most often make a TestFlight upload fail, before you archive.
#
#   bash scripts/preflight-testflight.sh
#
# It reads files only. It changes nothing.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ROOT
exec python3 - <<'PY'
import os, plistlib, re, shutil, struct, sys, json, zlib

root = os.environ["ROOT"]
fails, warns = [], []

def ok(msg):   print("  ok    " + msg)
def warn(msg): print("  WARN  " + msg); warns.append(msg)
def fail(msg): print("  FAIL  " + msg); fails.append(msg)

def read(path):
    try:
        return open(os.path.join(root, path)).read()
    except OSError:
        return None

yml = read("project.yml") or ""
def setting(name):
    m = re.search(r'^\s*' + name + r':\s*"?([^"\n]+?)"?\s*$', yml, flags=re.M)
    return m.group(1).strip() if m else None

# ---------------------------------------------------------------- app icon
print("App icon")
icon_dir = "App/Assets.xcassets/AppIcon.appiconset"
try:
    contents = json.load(open(os.path.join(root, icon_dir, "Contents.json")))
    name = contents["images"][0].get("filename")
except Exception:
    name = None
if not name:
    fail("No icon is installed. Run: bash scripts/add-logo.sh ~/Downloads/YOUR-LOGO-FILE")
else:
    path = os.path.join(root, icon_dir, name)
    try:
        data = open(path, "rb").read()
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            fail(f"{name} is not a PNG")
        else:
            width, height, depth, color_type = struct.unpack(">IIBB", data[16:26])
            has_alpha = color_type in (4, 6) or b"tRNS" in data[:4096]
            if (width, height) != (1024, 1024):
                fail(f"The icon is {width} x {height}, and Apple needs exactly 1024 x 1024")
            elif has_alpha:
                fail("The icon has transparency, and Apple rejects that. Run add-logo.sh again, it flattens it")
            else:
                ok("1024 x 1024 PNG, no transparency")
    except OSError:
        fail(f"{icon_dir}/{name} is listed but the file is missing")

# ---------------------------------------------------------------- identity and versions
print("Identity and version")
bundle = setting("PRODUCT_BUNDLE_IDENTIFIER")
if not bundle:
    fail("No bundle ID in project.yml")
elif "yourcompany" in bundle:
    fail(f"Bundle ID {bundle} is still the placeholder")
else:
    ok(f"Bundle ID {bundle}")
version, build = setting("MARKETING_VERSION"), setting("CURRENT_PROJECT_VERSION")
ok(f"Version {version}, build {build}")
print("        Every upload needs a build number higher than the last one.")
print("        Raise CURRENT_PROJECT_VERSION in project.yml, then run xcodegen generate.")

team = setting("DEVELOPMENT_TEAM")
if team:
    ok(f"Team ID saved ({team})")
else:
    warn("No Team ID in project.yml. After picking your Team in Xcode run: bash scripts/set-team.sh")

# ---------------------------------------------------------------- Firebase config
print("Firebase")
gsi_path = os.path.join(root, "App/GoogleService-Info.plist")
if not os.path.exists(gsi_path):
    fail("App/GoogleService-Info.plist is missing, so the app would skip sign-in and could not claim land")
else:
    try:
        gsi = plistlib.load(open(gsi_path, "rb"))
        if bundle and gsi.get("BUNDLE_ID") != bundle:
            fail(f"GoogleService-Info.plist is for {gsi.get('BUNDLE_ID')} but the app is {bundle}")
        else:
            ok("GoogleService-Info.plist matches the bundle ID")
    except Exception:
        fail("GoogleService-Info.plist could not be read")

# ---------------------------------------------------------------- Info.plist
print("Info.plist and privacy")
try:
    info = plistlib.load(open(os.path.join(root, "App/Info.plist"), "rb"))
    for key in ("NSLocationWhenInUseUsageDescription", "NSLocationAlwaysAndWhenInUseUsageDescription"):
        if info.get(key, "").strip():
            ok(key)
        else:
            fail(f"{key} is missing or empty, and Apple rejects apps that use location without it")
    modes = info.get("UIBackgroundModes", [])
    if "location" in modes and "audio" in modes:
        ok("Background modes: location and audio")
    else:
        fail(f"UIBackgroundModes should include location and audio, found {modes}")
except Exception:
    fail("App/Info.plist could not be read")

try:
    manifest = plistlib.load(open(os.path.join(root, "App/PrivacyInfo.xcprivacy"), "rb"))
    declared = [a["NSPrivacyAccessedAPIType"] for a in manifest.get("NSPrivacyAccessedAPITypes", [])]
    if "NSPrivacyAccessedAPICategoryUserDefaults" in declared:
        ok("Privacy manifest declares UserDefaults")
    else:
        fail("Privacy manifest does not declare UserDefaults, which the app uses")
except Exception:
    fail("App/PrivacyInfo.xcprivacy is missing or unreadable")

# ---------------------------------------------------------------- privacy page
print("Privacy page")
leftover = []
hosting = os.path.join(root, "Firebase/hosting")
if os.path.isdir(hosting):
    for f in os.listdir(hosting):
        if f.endswith(".html") and "YOUR-" in open(os.path.join(hosting, f)).read():
            leftover.append(f)
if leftover:
    warn("Placeholders are still in " + ", ".join(leftover) + ". Needed for external testing. Run: bash scripts/check-before-publish.sh")
else:
    ok("No placeholders left. Remember to deploy it: cd Firebase && npx -y firebase-tools@latest deploy --only hosting,functions")

# ---------------------------------------------------------------- disk space
print("Disk space")
free_gb = shutil.disk_usage(os.path.expanduser("~")).free / 1e9
if free_gb < 10:
    fail(f"Only {free_gb:.1f} GB free, and archiving needs about 10 GB. Clear space first")
else:
    ok(f"{free_gb:.0f} GB free")

print()
if fails:
    print(f"{len(fails)} problem(s) to fix before archiving, and {len(warns)} warning(s).")
    sys.exit(1)
print(f"Ready to archive. {len(warns)} warning(s).")
PY
