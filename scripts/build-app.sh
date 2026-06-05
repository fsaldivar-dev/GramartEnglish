#!/usr/bin/env bash
# Build the distributable GramartEnglish.app bundle.
#
# Flow:
#   1. Bundle the backend (Node + esbuild + native modules + corpus).
#   2. Build the Swift app in release mode.
#   3. Assemble GramartEnglish.app with Info.plist + bundled backend.
#   4. (Optional) ad-hoc codesign so Gatekeeper doesn't quarantine it locally.
#
# Output: ./dist/GramartEnglish.app
#
# Run from the repo root.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="$REPO_ROOT/dist"
APP="$DIST/GramartEnglish.app"
SWIFT_BIN="$REPO_ROOT/app/GramartEnglish/.build/arm64-apple-macosx/release/GramartEnglish"
BACKEND_BUNDLE="$REPO_ROOT/app/GramartEnglish/Resources/backend"
APP_ICON="$REPO_ROOT/app/GramartEnglish/Resources/AppIcon.icns"
VERSION="$(node -p "require('$REPO_ROOT/version.json').version")"

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
  echo "[build-app] expected arm64, got $ARCH — abort" >&2
  exit 1
fi

# Step 1: bundle the backend (idempotent — re-runs every time so we never
# distribute a stale bundle next to a freshly built binary).
echo "[build-app] step 1/4: packaging backend"
"$REPO_ROOT/scripts/package-backend.sh"

# Step 2: build the Swift app in release.
echo "[build-app] step 2/4: building Swift app (release)"
pushd "$REPO_ROOT/app/GramartEnglish" > /dev/null
swift build -c release
popd > /dev/null
if [[ ! -x "$SWIFT_BIN" ]]; then
  echo "[build-app] expected Swift binary at $SWIFT_BIN — abort" >&2
  exit 1
fi

# Step 3: assemble the .app bundle.
echo "[build-app] step 3/4: assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Executable + bundled backend
cp "$SWIFT_BIN" "$APP/Contents/MacOS/GramartEnglish"
chmod +x "$APP/Contents/MacOS/GramartEnglish"
cp -R "$BACKEND_BUNDLE" "$APP/Contents/Resources/backend"

# App icon. If the source .icns is missing (fresh checkout), regenerate.
if [[ ! -f "$APP_ICON" ]]; then
  echo "[build-app] AppIcon.icns missing — regenerating"
  "$REPO_ROOT/scripts/build-icon.sh"
fi
cp "$APP_ICON" "$APP/Contents/Resources/AppIcon.icns"

# Info.plist — minimum macOS app declaration.
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>      <string>en</string>
    <key>CFBundleExecutable</key>             <string>GramartEnglish</string>
    <key>CFBundleIconFile</key>               <string>AppIcon</string>
    <key>CFBundleIdentifier</key>             <string>com.gramart.english</string>
    <key>CFBundleInfoDictionaryVersion</key>  <string>6.0</string>
    <key>CFBundleName</key>                   <string>GramartEnglish</string>
    <key>CFBundlePackageType</key>            <string>APPL</string>
    <key>CFBundleShortVersionString</key>     <string>$VERSION</string>
    <key>CFBundleVersion</key>                <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>         <string>14.0</string>
    <key>NSHighResolutionCapable</key>        <true/>
    <key>NSHumanReadableCopyright</key>       <string>© 2026 GramartEnglish. Local-only, no telemetry.</string>
    <key>LSApplicationCategoryType</key>      <string>public.app-category.education</string>
</dict>
</plist>
EOF

# PkgInfo — legacy but expected by some Finder code paths.
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Step 4: ad-hoc codesign so launching from /Applications doesn't trip on
# unsigned-bundle warnings during local dev. Real distribution requires a
# Developer ID — see scripts/sign-and-notarize.sh.
echo "[build-app] step 4/4: ad-hoc codesign"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || {
  echo "[build-app] warn: ad-hoc codesign failed (non-fatal)"
}

SIZE_BYTES=$(du -sk "$APP" | awk '{print $1}')
SIZE_MB=$((SIZE_BYTES / 1024))
echo "[build-app] done. $APP ($SIZE_MB MB)"
echo "[build-app] launch with:  open '$APP'"
