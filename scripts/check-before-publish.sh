#!/usr/bin/env bash
# Stops you from publishing the privacy page with the placeholders still in it.
#
#   bash scripts/check-before-publish.sh
#
# Then, if it says ready:  cd Firebase && npx -y firebase-tools@latest deploy --only hosting
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOSTING="$ROOT/Firebase/hosting"

if grep -rn "YOUR-" "$HOSTING" --include='*.html' >/tmp/loopd-placeholders.txt 2>/dev/null && [ -s /tmp/loopd-placeholders.txt ]; then
  echo "Not ready. These placeholders still need your details:"
  echo ""
  cut -c1-160 /tmp/loopd-placeholders.txt
  echo ""
  echo "Fill them in with (use your own values):"
  echo "  sed -i '' 's/YOUR-CONTACT-EMAIL/you@example.com/g; s/YOUR-NAME-OR-COMPANY/Your Name/g' Firebase/hosting/*.html"
  echo ""
  echo "Use the name on your Apple Developer account, because that is the name shown on the App Store."
  rm -f /tmp/loopd-placeholders.txt
  exit 1
fi
rm -f /tmp/loopd-placeholders.txt

echo "Ready. No placeholders left in the privacy page."
echo "Publish with:  cd Firebase && npx -y firebase-tools@latest deploy --only hosting"
