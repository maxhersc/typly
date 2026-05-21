#!/bin/bash
set -e

echo "Building Typly..."
swift build -c release

echo "Creating App Bundle..."
APP_NAME="Typly.app"
rm -rf "$APP_NAME"
mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

cp Info.plist "$APP_NAME/Contents/"
cp .build/release/Typly "$APP_NAME/Contents/MacOS/Typly"

echo "Build complete. Output: $APP_NAME"
