#!/bin/zsh
# Builds the release zip for GitHub, signed with the "EasyNotch Developer" certificate
# (a self-signed certificate in the login keychain, see docs/DEVELOPMENT.md → Releasing).
#
#   scripts/release.sh
#
# Output: dist/EasyNotch-<version>.zip and its .sha256 checksum.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${SIGNING_IDENTITY:-EasyNotch Developer}"
VERSION=$(sed -nE 's/^ *MARKETING_VERSION: "(.*)"/\1/p' project.yml)
APP="build/release/Build/Products/Release/EasyNotch.app"
ZIP="dist/EasyNotch-$VERSION.zip"

echo "▸ Building EasyNotch $VERSION (Release)"
xcodegen generate --quiet
xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -configuration Release \
    -derivedDataPath build/release build -quiet

# Re-sign with the release certificate, so the app carries no personal details. Hardened
# Runtime stays on, and only the app's own entitlements are included (no debugging ones).
echo "▸ Signing with \"$IDENTITY\""
codesign --force --options runtime --timestamp=none \
    --entitlements EasyNotch/Resources/EasyNotch.entitlements \
    --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -E "^(Authority|TeamIdentifier|Identifier)="

echo "▸ Packaging"
mkdir -p dist
rm -f "$ZIP" "$ZIP.sha256"
ditto -c -k --keepParent "$APP" "$ZIP"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
cat "$ZIP.sha256"
echo "✓ $ZIP"
