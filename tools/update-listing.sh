#!/usr/bin/env bash
# Sends docs/description.txt as the experience description through Open Cloud.
# Needs ROBLOX_API_KEY with write access to the experience (Universe) and ROBLOX_UNIVERSE_ID.
set -euo pipefail
: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
: "${ROBLOX_UNIVERSE_ID:?set ROBLOX_UNIVERSE_ID}"

cd "$(dirname "$0")/.."
body="$(python3 -I -c 'import json,sys; print(json.dumps({"description": open("docs/description.txt").read().strip()}))')"

curl --fail-with-body -sS -X PATCH \
  "https://apis.roblox.com/cloud/v2/universes/${ROBLOX_UNIVERSE_ID}?updateMask=description" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$body"
echo
