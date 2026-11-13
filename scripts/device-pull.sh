#!/bin/bash
# Copy the app's log folders (events.log + snap-*.jpg per launch) off the paired Vision Pro.
# Usage: scripts/device-pull.sh [destination]    (default: device-logs/, git-ignored)
# Prints the newest launch folder last.
set -euo pipefail
source "$(dirname "$0")/_device.sh"

DEST="${1:-device-logs}"
mkdir -p "$DEST"
xcrun devicectl device copy from --device "$UDID" --domain-type appDataContainer --domain-identifier "$BUNDLE_ID" \
  --source Documents/logs --destination "$DEST" >/dev/null
ls -1d "$DEST"/*/ | sort | tail -5
