#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
: "${VERSION:?Set VERSION}"
: "${APPLE_ID:?Set APPLE_ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
export REQUIRE_SIGNING=1
./scripts/build-app.sh
APP="$PWD/dist/MacDuo.app"
SUBMISSION="$PWD/.build/notary-submission.zip"
ditto -c -k --keepParent "$APP" "$SUBMISSION"
xcrun notarytool submit "$SUBMISSION" --apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
mkdir -p dist/release
ZIP="$PWD/dist/release/MacDuo-${VERSION}-universal.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
STAGE=$(mktemp -d "${TMPDIR:-/tmp/}macduo-dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/MacDuo.app"
ln -s /Applications "$STAGE/Applications"
DMG="$PWD/dist/release/MacDuo-${VERSION}-universal.dmg"
hdiutil create -ov -volname MacDuo -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --force --sign "$CODE_SIGN_IDENTITY" --keychain "$SIGNING_KEYCHAIN" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
(cd dist/release && shasum -a 256 *.zip *.dmg > SHA256SUMS.txt)
