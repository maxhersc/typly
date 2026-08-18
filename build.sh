#!/bin/bash
set -euo pipefail

APP_NAME="Typly.app"

# TCC identifies apps by code signature, so an unsigned bundle gets a brand new
# identity on every build and the Accessibility permission you granted stops
# applying — the app just looks untrusted again. Ad-hoc signing ("-") keeps a
# single build stable; export TYPLY_SIGN_IDENTITY with a Developer ID certificate
# to keep the grant across rebuilds.
SIGN_IDENTITY="${TYPLY_SIGN_IDENTITY:--}"

echo "Building Typly..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

cp Info.plist "$APP_NAME/Contents/"
printf 'APPL????' > "$APP_NAME/Contents/PkgInfo"
cp .build/release/Typly "$APP_NAME/Contents/MacOS/Typly"

echo "Signing with identity: $SIGN_IDENTITY"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_NAME"
codesign --verify --verbose=2 "$APP_NAME"

echo "Build complete. Output: $APP_NAME"
echo
echo "If Accessibility permission stops working after a rebuild, remove Typly from"
echo "System Settings > Privacy & Security > Accessibility and add it again."
