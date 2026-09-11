#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="VPN"
BUNDLE_ID="com.artem.velvetvpn"
SIMULATOR_NAME="${SIMULATOR_NAME:-iPhone 17 Pro}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT/.build/DerivedData}"

UDID="$(
  xcrun simctl list devices available |
    rg "$SIMULATOR_NAME \\(" |
    head -1 |
    rg -o '[A-F0-9-]{36}'
)"

if [[ -z "$UDID" ]]; then
  echo "No available simulator named \"$SIMULATOR_NAME\"." >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
open -a Simulator --args -CurrentDeviceUDID "$UDID"

echo "Building $SCHEME for $SIMULATOR_NAME ($UDID)..."
xcodebuild \
  -project "$ROOT/VPN.xcodeproj" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/VPN.app"

xcrun simctl install "$UDID" "$APP_PATH"
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true

# simctl launch can block on some Xcode/Simulator versions; run detached.
LAUNCH_FLAGS="${LAUNCH_FLAGS:---promo-demo}"
# shellcheck disable=SC2086
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" --show-home --panel-island $LAUNCH_FLAGS >/dev/null 2>&1 &
sleep 2

echo "Prototype launched on $SIMULATOR_NAME with --show-home --panel-island ${LAUNCH_FLAGS}."
