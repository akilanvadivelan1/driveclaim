#!/usr/bin/env bash
# Saves your Apple Developer Team ID into project.yml, so Xcode stops forgetting your Team
# every time you run `xcodegen generate`.
#
# Do this once:
#   1. xcodegen generate && open Loopd.xcodeproj
#   2. In Xcode, pick your Team under Signing & Capabilities
#   3. bash scripts/set-team.sh
#
# Your Team ID is not a secret. It appears in every app you ship.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PBX="$ROOT/Loopd.xcodeproj/project.pbxproj"
YML="$ROOT/project.yml"

if [ ! -f "$PBX" ]; then
  echo "Could not find Loopd.xcodeproj. Run:  xcodegen generate"
  exit 1
fi

TEAM="$(grep -o 'DEVELOPMENT_TEAM = [A-Z0-9]\{10\};' "$PBX" | head -1 | sed 's/DEVELOPMENT_TEAM = \(.*\);/\1/' || true)"
if [ -z "$TEAM" ]; then
  echo "No Team is selected yet. Open Loopd.xcodeproj, click the blue Loopd icon,"
  echo "then the Loopd target, then Signing & Capabilities, and pick your Team."
  echo "Then run this script again."
  exit 1
fi

python3 - "$YML" "$TEAM" <<'PY'
import re, sys
path, team = sys.argv[1], sys.argv[2]
s = open(path).read()
if re.search(r'^\s*DEVELOPMENT_TEAM:', s, flags=re.M):
    s = re.sub(r'^(\s*)DEVELOPMENT_TEAM:.*$', r'\1DEVELOPMENT_TEAM: ' + team, s, flags=re.M)
else:
    anchor = re.search(r'^(\s*)ASSETCATALOG_COMPILER_APPICON_NAME:.*$', s, flags=re.M)
    if not anchor:
        sys.exit("Could not find the settings block in project.yml")
    s = s[:anchor.end()] + "\n" + anchor.group(1) + "DEVELOPMENT_TEAM: " + team + s[anchor.end():]
open(path, "w").write(s)
PY

echo "Saved your Team ID ($TEAM) in project.yml."
echo "Now xcodegen generate keeps your Team. Commit it if you like:  git add project.yml"
