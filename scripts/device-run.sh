#!/bin/bash
# Build → install → launch on the paired Vision Pro and stream the app's event log (stdout) live.
# Usage: scripts/device-run.sh [--no-build] [-startURL https://…]   — Ctrl-C ends the stream and the app.
# The same lines are written on the device to Documents/logs/<launch>/events.log (scripts/device-pull.sh).
set -euo pipefail
source "$(dirname "$0")/_device.sh"

BUILD=1
if [ "${1:-}" = "--no-build" ]; then BUILD=0; shift; fi

if [ "$BUILD" = 1 ]; then
  export PATH="$HOME/.local/bin:/opt/homebrew/bin:$PATH"
  xcodegen generate -q
  xcodebuild -project CoupangPlayVP.xcodeproj -scheme CoupangPlayVP -destination "id=$UDID" \
    -derivedDataPath build -allowProvisioningUpdates build -quiet
  xcrun devicectl device install app --device "$UDID" build/Build/Products/Debug-xros/CoupangPlayVP.app >/dev/null
  echo "installed $BUNDLE_ID on $UDID" >&2
fi

exec xcrun devicectl device process launch --device "$UDID" --terminate-existing --console "$BUNDLE_ID" "$@"
