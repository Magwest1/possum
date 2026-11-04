#!/usr/bin/env bash
# Builds Possum.app from the Swift package and signs it.
#
# Environment:
#   SIGN_IDENTITY  codesign identity (default "-" = ad-hoc, for local use only)
#   ARCHS          architectures to build (default: "arm64 x86_64")
#   BUILD_NUMBER   CFBundleVersion (default: git commit count, else 1)
#   OUTPUT_DIR     where Possum.app is written (default: build)
set -euo pipefail

cd "$(dirname "$0")/.."

SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ARCHS="${ARCHS:-arm64 x86_64}"
OUTPUT_DIR="${OUTPUT_DIR:-build}"
VERSION="$(tr -d '[:space:]' < version.txt)"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"
APP_ID="io.github.magwest1.possum"
HELPER_ID="io.github.magwest1.possum.helper"
APP="$OUTPUT_DIR/Possum.app"

echo "==> Building Possum $VERSION ($BUILD_NUMBER) for: $ARCHS"
app_bins=()
helper_bins=()
for arch in $ARCHS; do
  # Separate scratch paths keep per-arch products from overwriting each other.
  build_flags=(-c release --arch "$arch" --scratch-path ".build/release-$arch")
  swift build "${build_flags[@]}" --product Possum
  swift build "${build_flags[@]}" --product PossumHelper
  bin_dir="$(swift build "${build_flags[@]}" --show-bin-path)"
  app_bins+=("$bin_dir/Possum")
  helper_bins+=("$bin_dir/PossumHelper")
done

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Library/LaunchDaemons"
lipo -create "${app_bins[@]}" -output "$APP/Contents/MacOS/Possum"
lipo -create "${helper_bins[@]}" -output "$APP/Contents/MacOS/PossumHelper"

sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Support/Info.plist > "$APP/Contents/Info.plist"
cp "Support/$HELPER_ID.plist" "$APP/Contents/Library/LaunchDaemons/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
cp Resources/MenuBar/*.png "$APP/Contents/Resources/"
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist" "$APP/Contents/Library/LaunchDaemons/$HELPER_ID.plist"

echo "==> Signing with identity: $SIGN_IDENTITY"
sign_flags=(--force --options runtime)
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "    (ad-hoc signature: fine for local testing, not for distribution)"
else
  sign_flags+=(--timestamp)
fi
codesign "${sign_flags[@]}" --sign "$SIGN_IDENTITY" --identifier "$HELPER_ID" \
  "$APP/Contents/MacOS/PossumHelper"
codesign "${sign_flags[@]}" --sign "$SIGN_IDENTITY" --identifier "$APP_ID" \
  --entitlements Support/Possum.entitlements "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
echo "==> Built $APP"
