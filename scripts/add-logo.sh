#!/usr/bin/env bash
# Puts your logo into Loopd as the app icon, the logo on the first screens, and the website's logo and icons.
#
#   bash scripts/add-logo.sh ~/Downloads/loopd-logo.png
#
# Needs a Mac (it uses the built-in `sips` tool). The logo must be square.
# Apple wants a 1024 x 1024 PNG with no transparency, and this script makes sure of that.
set -euo pipefail

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "Give me the logo file, for example:"
  echo "  bash scripts/add-logo.sh ~/Downloads/loopd-logo.png"
  exit 1
fi
if ! command -v sips >/dev/null 2>&1; then
  echo "This needs a Mac, because it uses the built-in sips tool."
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$ROOT/App/Assets.xcassets"
ICON_DIR="$ASSETS/AppIcon.appiconset"
MARK_DIR="$ASSETS/LogoMark.imageset"
if [ ! -d "$ICON_DIR" ] || [ ! -d "$MARK_DIR" ]; then
  echo "Could not find $ASSETS. Run git pull first."
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

prop() { sips -g "$1" "$2" | awk -v k="$1" '$1 == k":" {print $2}'; }

# 1. Make a PNG. If the original has transparency, flatten it, because App Store icons cannot have any.
if [ "$(prop hasAlpha "$SRC")" = "yes" ]; then
  echo "The logo has transparency, so it is being flattened (iOS rejects icons with transparency)."
  sips -s format jpeg -s formatOptions best "$SRC" --out "$TMP/flat.jpg" >/dev/null
  sips -s format png "$TMP/flat.jpg" --out "$TMP/icon.png" >/dev/null
else
  sips -s format png "$SRC" --out "$TMP/icon.png" >/dev/null
fi

# 2. Check the size.
W="$(prop pixelWidth "$TMP/icon.png")"
H="$(prop pixelHeight "$TMP/icon.png")"
if [ "$W" != "$H" ]; then
  echo "The logo must be square, and this one is ${W} x ${H}. Crop it to a square and try again."
  exit 1
fi
if [ "$W" -lt 1024 ]; then
  echo "Note: the logo is only ${W} pixels wide and is being enlarged to 1024, so it may look soft."
  echo "If you have a bigger original, use that instead."
fi
if [ "$W" != "1024" ]; then
  sips -z 1024 1024 "$TMP/icon.png" >/dev/null
fi

# 3. Install it twice: as the app icon, and as the logo drawn on the first screens.
cp "$TMP/icon.png" "$ICON_DIR/icon-1024.png"
cp "$TMP/icon.png" "$MARK_DIR/logo.png"

python3 - "$ICON_DIR/Contents.json" "$MARK_DIR/Contents.json" <<'PY'
import json, sys
for path, name in ((sys.argv[1], "icon-1024.png"), (sys.argv[2], "logo.png")):
    data = json.load(open(path))
    data["images"][0]["filename"] = name
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
PY

# 4. The website uses small copies of the same logo: the header, the browser tab, and the
#    icon iPhones use when someone adds the site to their home screen.
SITE="$ROOT/Firebase/hosting"
if [ -d "$SITE" ]; then
  small() { sips -z "$1" "$1" "$TMP/icon.png" --out "$2" >/dev/null; }
  small 192 "$SITE/logo.png"
  small 48  "$SITE/favicon.png"
  small 180 "$SITE/apple-touch-icon.png"
fi

echo ""
echo "Done. The logo is installed as the app icon and as the logo on the first screens and on the website."
echo "Next:  xcodegen generate && open Loopd.xcodeproj   then press Cmd + R."
echo "If the old icon still shows, delete Loopd from the phone and run it again."
