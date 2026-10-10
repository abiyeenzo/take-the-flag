#!/usr/bin/env bash
# Builds the place with Rojo and publishes it to Roblox through Open Cloud.
#
# Required environment variables:
#   ROBLOX_API_KEY      Open Cloud key with the "Place Publishing" permission for this experience
#   ROBLOX_UNIVERSE_ID  experience (universe) id
#   ROBLOX_PLACE_ID     place id of the start place
#
# Optional: VERSION_TYPE=Saved to upload without making it live (default is Published).
set -euo pipefail

: "${ROBLOX_API_KEY:?set ROBLOX_API_KEY}"
: "${ROBLOX_UNIVERSE_ID:?set ROBLOX_UNIVERSE_ID}"
: "${ROBLOX_PLACE_ID:?set ROBLOX_PLACE_ID}"
VERSION_TYPE="${VERSION_TYPE:-Published}"

cd "$(dirname "$0")/.."
mkdir -p build
rojo build default.project.json -o build/TakeTheFlag.rbxl

curl --fail-with-body -sS -X POST \
  "https://apis.roblox.com/universes/v1/${ROBLOX_UNIVERSE_ID}/places/${ROBLOX_PLACE_ID}/versions?versionType=${VERSION_TYPE}" \
  -H "x-api-key: ${ROBLOX_API_KEY}" \
  -H "Content-Type: application/octet-stream" \
  --data-binary @build/TakeTheFlag.rbxl
echo
