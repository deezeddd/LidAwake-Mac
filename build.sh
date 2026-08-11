#!/bin/bash
# Builds LidAwake.app and installs it into ~/Applications.
set -e
cd "$(dirname "$0")"

APP="$HOME/Applications/LidAwake.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Info.plist "$APP/Contents/Info.plist"
cp main.swift "$APP/Contents/Resources/main.swift"

swiftc -O -o "$APP/Contents/MacOS/LidAwake" main.swift \
    -F /System/Library/PrivateFrameworks -framework DisplayServices

codesign --force --sign - "$APP"
echo "Built and installed: $APP"
echo "Launch it with: open \"$APP\""
