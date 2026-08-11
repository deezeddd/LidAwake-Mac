#!/bin/bash
# One-line installer for LidAwake:
#   curl -fsSL https://raw.githubusercontent.com/deezeddd/LidAwake-Mac/main/install.sh | bash
# Downloads the source, builds it locally (a few seconds), installs to ~/Applications.
set -e

if ! command -v swiftc >/dev/null 2>&1; then
    echo "LidAwake builds from source and needs the Xcode Command Line Tools."
    echo "Install them first with:  xcode-select --install"
    echo "Then re-run this installer."
    exit 1
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Downloading LidAwake..."
curl -fsSL https://github.com/deezeddd/LidAwake-Mac/archive/refs/heads/main.tar.gz | tar -xz -C "$TMP" --strip-components=1

cd "$TMP"
./build.sh

echo
echo "Installed: ~/Applications/LidAwake.app"
echo
echo "Recommended one-time step (lets the toggle work without a password prompt):"
echo "  bash ~/Applications/LidAwake.app/Contents/Resources/setup-permissions.sh"
echo
echo "Launch it with:"
echo "  open ~/Applications/LidAwake.app"
