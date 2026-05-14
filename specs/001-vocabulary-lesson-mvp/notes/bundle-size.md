# Bundle size tracking

Constitution VIII budget: **≤ 80 MB compressed** for the embedded backend bundle inside `GramartEnglish.app/Contents/Resources/backend/`.

## How to measure

```bash
./scripts/package-backend.sh
du -sh app/GramartEnglish/Resources/backend
ditto -c -k --keepParent app/GramartEnglish/Resources/backend /tmp/backend.zip
ls -lh /tmp/backend.zip
```

## Log

| Date | Commit | Uncompressed | Compressed (zip) | Notes |
|------|--------|--------------|------------------|-------|
| — | — | — | — | First measurement scheduled before MVP release |

## Levers if we exceed 80 MB

1. Strip `node_modules/` to runtime-only deps (production install already drops dev deps).
2. Replace `pino-pretty` import (only used in dev) with an env-gated dynamic import.
3. Compile native modules with `--release` and strip debug symbols (`strip` on `.node` files).
4. Drop language-data assets from sub-dependencies (e.g. icu in some sqlite builds).
5. Switch from full `node` binary to a custom-built Node distribution.
