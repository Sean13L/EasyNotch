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
# Build unsigned. Re-signing an app Xcode already signed leaves bytes of the old Apple
# Development signature behind in the binary, and that certificate's name contains the
# owner's email address.
rm -rf build/release
xcodebuild -project EasyNotch.xcodeproj -scheme EasyNotch -configuration Release \
    -derivedDataPath build/release build -quiet CODE_SIGNING_ALLOWED=NO

# Sign with the release certificate, so the app carries no personal details. Hardened
# Runtime stays on, and only the app's own entitlements are included (no debugging ones).
echo "▸ Signing with \"$IDENTITY\""
codesign --force --options runtime --timestamp=none \
    --entitlements EasyNotch/Resources/EasyNotch.entitlements \
    --sign "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
codesign -dvv "$APP" 2>&1 | grep -E "^(Authority|TeamIdentifier|Identifier)="

# Never ship anything from the development certificate.
if LC_ALL=C grep -rqa "Apple Development" "$APP"; then
    echo "✗ The app still contains an Apple Development certificate. Not packaging." >&2
    exit 1
fi

echo "▸ Packaging"
mkdir -p dist
rm -f "$ZIP" "$ZIP.sha256"
ditto -c -k --keepParent "$APP" "$ZIP"
(cd dist && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256")
cat "$ZIP.sha256"
echo "✓ $ZIP"
