#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="VPN"
ARCHIVE_PATH="$ROOT/build/VPN.xcarchive"
EXPORT_PATH="$ROOT/build/export"
EXPORT_OPTIONS="$ROOT/ExportOptions.plist"

cd "$ROOT"

echo "→ Archiving $SCHEME (Release)…"
xcodebuild \
  -project "$ROOT/VPN.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "→ Uploading to App Store Connect / TestFlight…"
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

echo ""
echo "Готово. Билд отправлен в App Store Connect."
echo "Открой https://appstoreconnect.apple.com → Apps → Velvet → TestFlight"
echo "Через 5–15 минут билд появится для тестирования."
