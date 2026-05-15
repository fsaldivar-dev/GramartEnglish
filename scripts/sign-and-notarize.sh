#!/usr/bin/env bash
# Sign and notarize the GramartEnglish.app.
#
# Prerequisites (set as env vars or use a keychain profile):
#   DEVELOPER_ID_APPLICATION  — full Developer ID Application identity name
#                               (e.g. "Developer ID Application: ACME Inc (TEAMID)")
#   APPLE_NOTARIZE_PROFILE    — name of a stored notarytool keychain profile
#                               (xcrun notarytool store-credentials)
#
# Usage: scripts/sign-and-notarize.sh path/to/GramartEnglish.app
#
# Notes (Constitution VI):
#   - The app is built with the Hardened Runtime.
#   - It must NOT have com.apple.security.network.client / .server entitlements;
#     the embedded backend binds only to 127.0.0.1 (which the sandbox allows
#     between the parent and its child process).

set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "Usage: $0 /path/to/GramartEnglish.app" >&2
  exit 1
fi

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION}"
: "${APPLE_NOTARIZE_PROFILE:?Set APPLE_NOTARIZE_PROFILE (notarytool keychain profile name)}"

ENTITLEMENTS="$(mktemp -t entitlements).plist"
cat > "$ENTITLEMENTS" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key><true/>
  <!-- Allow spawning the embedded backend child process -->
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key><false/>
  <key>com.apple.security.cs.disable-library-validation</key><false/>
  <!-- INTENTIONALLY NO network entitlements -->
</dict>
</plist>
EOF

echo "[sign] signing nested executables and frameworks"
find "$APP/Contents/Resources/backend" -type f \( -name node -o -name '*.node' \) | while read -r bin; do
  codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" \
           --entitlements "$ENTITLEMENTS" "$bin"
done

echo "[sign] signing the .app bundle"
codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" \
         --entitlements "$ENTITLEMENTS" "$APP"

echo "[sign] verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP" || true

echo "[notarize] zipping for upload"
ZIP="$(dirname "$APP")/GramartEnglish.zip"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "[notarize] submitting"
xcrun notarytool submit "$ZIP" --keychain-profile "$APPLE_NOTARIZE_PROFILE" --wait

echo "[notarize] stapling"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

rm -f "$ZIP"
echo "[done] signed + notarized: $APP"
