#!/usr/bin/env bash
# Generate AppIcon.icns + AppIcon.iconset from a procedural Swift drawing.
#
#   1. swift scripts/make-icon.swift produces icon_1024.png at 1024×1024.
#   2. `sips` downsamples to every size the .iconset requires.
#   3. `iconutil` packs the .iconset into a single .icns blob.
#
# Output: app/GramartEnglish/Resources/AppIcon.icns
#
# Idempotent — re-runs are safe.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$REPO_ROOT/app/GramartEnglish/Resources"
ICONSET="$OUT_DIR/AppIcon.iconset"
ICNS="$OUT_DIR/AppIcon.icns"
SEED="$OUT_DIR/icon_1024.png"

mkdir -p "$OUT_DIR" "$ICONSET"

echo "[build-icon] drawing 1024×1024 source PNG"
swift "$REPO_ROOT/scripts/make-icon.swift" "$SEED"

# AppIcon.iconset spec — Apple-mandated filenames + sizes.
declare -a SIZES=(
  "16:icon_16x16.png"
  "32:icon_16x16@2x.png"
  "32:icon_32x32.png"
  "64:icon_32x32@2x.png"
  "128:icon_128x128.png"
  "256:icon_128x128@2x.png"
  "256:icon_256x256.png"
  "512:icon_256x256@2x.png"
  "512:icon_512x512.png"
  "1024:icon_512x512@2x.png"
)

echo "[build-icon] downsampling via sips"
for entry in "${SIZES[@]}"; do
  size="${entry%%:*}"
  name="${entry#*:}"
  sips -z "$size" "$size" "$SEED" --out "$ICONSET/$name" > /dev/null
done

echo "[build-icon] packing $ICNS"
iconutil -c icns "$ICONSET" -o "$ICNS"

# Sanity report.
ls -la "$ICNS"
echo "[build-icon] done"
