# GramartEnglish macOS app

This folder holds the SwiftUI macOS application and its local Swift packages.

## Layout

```
app/
├── GramartEnglish/             # The app target (SwiftPM executable)
│   ├── Package.swift
│   ├── Sources/                # App source organized by feature
│   └── Tests/                  # XCTest unit / UI / perf
└── Packages/
    ├── LessonKit/              # Pure-Swift lesson state machine
    └── BackendClient/          # Typed HTTP client for the embedded backend
```

## Why SwiftPM instead of an `.xcodeproj`

The plan calls for `app/GramartEnglish.xcodeproj`. During scaffolding we use a
SwiftPM `Package.swift` executable target because:

- It builds and tests headlessly from CI without committing a large `.pbxproj`.
- Xcode 14+ opens a `Package.swift` directly as a fully-functional project,
  with Run, Test, schemes, and Previews. No information is lost.
- For final distribution (Phase 7: notarized `.app`), we will either generate
  an `.xcodeproj` from a small `project.yml` via XcodeGen, or wrap the target
  in Xcode's "App from Swift Package" workflow at that point.

## Build & run (local)

```bash
# Run the app shell
cd app/GramartEnglish
swift run

# Open in Xcode (recommended for SwiftUI previews)
open Package.swift
```

## Test

```bash
cd app/Packages/LessonKit && swift test
cd app/Packages/BackendClient && swift test
cd app/GramartEnglish && swift test
```

## Linting

`.swiftlint.yml` at this folder's root applies to every Swift source under it.
Install SwiftLint with `brew install swiftlint`, then run `swiftlint` from
`app/`.
