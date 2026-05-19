#!/usr/bin/env bash
# Bundle the Node.js backend so it can be embedded inside the GramartEnglish.app.
#
# Output layout under app/GramartEnglish/Resources/backend/:
#   node                # arm64 Node 20 LTS binary
#   bundle.cjs          # esbuild-bundled backend entrypoint
#   node_modules/       # native modules only (better-sqlite3, hnswlib-node)
#   data/               # CEFR corpus snapshot
#
# Run from the repo root. Requires: Node 20 LTS active, pnpm 9, jq.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND="$REPO_ROOT/backend"
OUTPUT="$REPO_ROOT/app/GramartEnglish/Resources/backend"

ARCH="$(uname -m)"
if [[ "$ARCH" != "arm64" ]]; then
  echo "[package-backend] expected arm64, got $ARCH — abort" >&2
  exit 1
fi

NODE_BIN="$(command -v node)"
NODE_VERSION="$(node -p 'process.versions.node')"
if [[ ! "$NODE_VERSION" =~ ^20\. ]]; then
  echo "[package-backend] requires Node 20 LTS, found $NODE_VERSION — abort" >&2
  exit 1
fi

echo "[package-backend] cleaning $OUTPUT"
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"

echo "[package-backend] installing prod deps"
pushd "$BACKEND" > /dev/null
pnpm install --prod --frozen-lockfile

echo "[package-backend] bundling backend with esbuild"
node_modules/.bin/esbuild src/server.ts \
  --bundle \
  --platform=node \
  --target=node20 \
  --format=cjs \
  --external:better-sqlite3 \
  --external:hnswlib-node \
  --external:fastify \
  --external:fastify-plugin \
  --external:pino \
  --external:pino-pretty \
  --external:zod \
  --external:js-yaml \
  --external:ollama \
  --outfile="$OUTPUT/bundle.cjs"

echo "[package-backend] copying runtime + native modules"
cp "$NODE_BIN" "$OUTPUT/node"
chmod +x "$OUTPUT/node"
mkdir -p "$OUTPUT/node_modules"
# Copy the full node_modules tree (smallest correct option for native modules).
cp -R node_modules "$OUTPUT/"

popd > /dev/null

echo "[package-backend] copying CEFR corpus"
cp -R "$REPO_ROOT/data" "$OUTPUT/data"

echo "[package-backend] copying contracts (used by openapiLoader)"
mkdir -p "$OUTPUT/specs/001-vocabulary-lesson-mvp/contracts"
cp "$REPO_ROOT/specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml" \
   "$OUTPUT/specs/001-vocabulary-lesson-mvp/contracts/openapi.yaml"

echo "[package-backend] copying version.json"
cp "$REPO_ROOT/version.json" "$OUTPUT/version.json"

SIZE_BYTES=$(du -sk "$OUTPUT" | awk '{print $1}')
SIZE_MB=$((SIZE_BYTES / 1024))
echo "[package-backend] bundle size: ${SIZE_MB} MB (uncompressed)"
echo "[package-backend] target: ≤ 80 MB compressed (Constitution VIII)"
echo "[package-backend] done. Output at $OUTPUT"
