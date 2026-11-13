# Shared by device-*.sh: Xcode location, the paired Vision Pro, the app's bundle id.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."

device_udid() {
  if [ -n "${CPVP_DEVICE:-}" ]; then echo "$CPVP_DEVICE"; return; fi
  xcrun devicectl list devices 2>/dev/null | awk '/Vision Pro/ && /physical/ && /connected/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) { print $i; exit } }'
}

bundle_id() {
  xcodebuild -project CoupangPlayVP.xcodeproj -scheme CoupangPlayVP -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/^ *PRODUCT_BUNDLE_IDENTIFIER = / && $2 !~ /tests$/ { print $2; exit }'
}

UDID="$(device_udid)"
[ -n "$UDID" ] || { echo "연결된 Vision Pro가 없습니다 (xcrun devicectl list devices)" >&2; exit 1; }
BUNDLE_ID="$(bundle_id)"
