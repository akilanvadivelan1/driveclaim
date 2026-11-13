#!/usr/bin/env bash
# Stops you from publishing the website with anything unfinished.
#
#   bash scripts/check-before-publish.sh
#
# Then, if it says ready:  cd Firebase && npx -y firebase-tools@latest deploy --only hosting
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOSTING="$ROOT/Firebase/hosting"
bad=0

# 1. No placeholders left in the pages.
found="$(grep -rn "YOUR-" "$HOSTING" --include='*.html' 2>/dev/null | cut -c1-160 || true)"
if [ -n "$found" ]; then
  bad=1
  echo "Not ready. These placeholders still need your details:"
  echo ""
  echo "$found"
  echo ""
  echo "Fill them in with (use your own values):"
  echo "  sed -i '' 's/YOUR-CONTACT-EMAIL/you@example.com/g; s/YOUR-NAME-OR-COMPANY/Your Name/g' Firebase/hosting/*.html"
  echo ""
  echo "Use the name on your Apple Developer account, because that is the name shown on the App Store."
  echo ""
fi

# 2. The logo files the pages point at.
missing=""
for f in logo.png favicon.png apple-touch-icon.png; do
  [ -f "$HOSTING/$f" ] || missing="$missing $f"
done
if [ -n "$missing" ]; then
  bad=1
  echo "Not ready. These logo files are missing from Firebase/hosting:$missing"
  echo "Make them from your logo with:  bash scripts/add-logo.sh ~/Downloads/YOUR-LOGO-FILE"
  echo ""
fi

# 3. The site's own checks (numbers match the drawing, no scripts or gradients, links work).
if ! report="$(python3 "$ROOT/scripts/check-site.py" 2>&1)"; then
  bad=1
  echo "Not ready. The site checks failed:"
  echo ""
  echo "$report" | grep -E "FAIL|problem"
  echo ""
fi

if [ "$bad" -ne 0 ]; then
  exit 1
fi

echo "Ready. The site is complete and the checks pass."
echo "Publish with:  cd Firebase && npx -y firebase-tools@latest deploy --only hosting"
