#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/TouchMyMac.xcodeproj"
SCHEME="TouchMyMac"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
APP_NAME="TouchMyMac"
DMG_NAME="TouchMyMac-Universal.dmg"

echo "=================================================="
echo " Building $APP_NAME (Universal: arm64 + x86_64) "
echo "=================================================="

mkdir -p "$OUTPUT_DIR"
rm -rf "$DERIVED_DATA_PATH"

echo "==> Compiling Universal Binary ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk macosx \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -d "$BUILT_APP_PATH" ]]; then
  echo "Error: Build succeeded but app not found at: $BUILT_APP_PATH" >&2
  exit 1
fi

echo "==> Verifying architectures..."
lipo -info "$BUILT_APP_PATH/Contents/MacOS/$APP_NAME"

echo "==> Applying Ad-Hoc code signature (required for Apple Silicon)..."
codesign --force --deep --sign - "$BUILT_APP_PATH"

echo "==> Preparing DMG staging folder..."
STAGING_DIR="$(mktemp -d -t tmm_dmg_staging.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

cp -R "$BUILT_APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Packaging DMG..."
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "=================================================="
echo " BUILD SUCCESSFUL!"
echo " DMG Location: $DMG_PATH"
echo " Size: $(du -h "$DMG_PATH" | cut -f1)"
echo " SHA256: $(shasum -a 256 "$DMG_PATH" | cut -d' ' -f1)"
echo "=================================================="
