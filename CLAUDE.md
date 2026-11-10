# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Index

- **Overview** — offline-first POS app, Swift/SwiftUI via Skip (iOS + Android), SQLite source of truth syncing to Firestore.
- **Layout** — `app/` (Skip app shell) + `libraries/Apoorva*` (independent SwiftPM packages); open `app/Project.xcworkspace` in Xcode.
- **Module dependency graph** — chain from `ApoorvaModels` up through `ApoorvaOfflineStorage` → `ApoorvaServices`/`ApoorvaRepository` → `ApoorvaModules` → `ApoorvaAppCore` → app.
- **Commands** — **mandatory:** use `scripts/build.sh`/`scripts/toggle-library.sh`; never call `xcodebuild`, `swift build`, or `swift test` directly.
- **Conventions** — Swift 6 strict concurrency; never edit generated Kotlin or anything under `.build/`; never write files via Bash heredoc or run `git merge`/`gh pr merge`.
- **Docs** — `docs/01`–`docs/12` cover product/architecture/security/etc.; check before product or architecture decisions.
- **Decisions log** — `docs/decisions/`: check before re-exploring a topic; a `Stop` hook blocks ending a session that explored code or exited plan mode without adding an entry there.

## Overview

Apoorva is an offline-first POS / business management app written in Swift + SwiftUI and built for iOS and Android with [Skip](https://skip.dev). Local SQLite is the source of truth; data syncs to Firebase Firestore in the background.

## Layout

- `app/` — the Skip app shell (`Package.swift` with the `skipstone` plugin, `Skip.env`, `Darwin/` Xcode project, `Android/` Gradle project). `app/Sources/Apoorva/Skip/skip.yml` uses `mode: 'native'` (Skip Fuse). `Skip.env` currently sets `SKIP_NO_ANDROID=1`, so Android builds are disabled by default.
- `libraries/Apoorva*` — independent local SwiftPM packages, each with its own `Package.swift` and `Tests/`. These are plain Swift packages (no skipstone plugin). `ApoorvaUI` and `ApoorvaViewModel` are empty placeholders.
- Open `app/Project.xcworkspace` in Xcode to develop the app and libraries together.

## Module dependency graph

```
app (Apoorva) → ApoorvaAppCore → ApoorvaModules → ApoorvaRepository → ApoorvaOfflineStorage → ApoorvaModels → ApoorvaUtilities
                                              ↘ ApoorvaUtilities          ↘ ApoorvaServices → ApoorvaModels
```

- **ApoorvaModels** — pure data models (`Codable`, `SQLCodable`).
- **ApoorvaOfflineStorage** — local DB layer. Contains two backends: `SkipSQL/` (`SkipSqlDatabase`, currently wired into the app) and `GRDB/` (`AppDatabase`, migrations, `+GRDB` model extensions). DAOs are protocol-based (e.g. `InventoryItemLocalStorageProtocol`).
- **ApoorvaServices** — Firebase (Auth, Firestore) via `firebase-ios-sdk` directly, e.g. `FirestoreSyncService`, `AuthService`; also `Observability/` for Analytics/Crashlytics/Performance (`AnalyticsServicing`, `CrashReportingServicing` and `PerformanceMonitoringServicing` are provider-agnostic; the `Firebase*Service` classes are the Firebase implementations).
- **ApoorvaRepository** — offline-first coordination between local storage and services.
- **ApoorvaModules** — feature SwiftUI views + `@Observable` view models (POS, Cashflow, DailyCashflowSummary, Inventory, Customers, Sale, Login, Profile).
- **ApoorvaAppCore** — composition root. `Containers/AppContainer.swift` builds `ServicesContainer`, `OfflineStorageContainer`, `RepositoryContainer`, `ModulesContainer` with lazy properties; no singletons. New dependencies get wired here and injected downward — the Analytics/Crashlytics/Performance services are wired in `ServicesContainer` the same way. Also holds `Router/` and the root `MainView`/`HomeView`.

## Commands

**Build and test rule (mandatory):** for any build or test of a library, run only the repo scripts. Never call `xcodebuild`, `swift build` or `swift test` directly, and never paste their raw output.

```bash
scripts/build.sh <Module|all> [build|test] [--coverage]               # prints SUCCESS/FAILED + root cause
scripts/install-tools.sh                                              # one-time: installs xcbeautify
scripts/toggle-library.sh {local|remote|status} [LibraryName]         # switch ManiSwiftUIComponents/ApoorvaUtilities between the sibling Libraries/ checkout and the pinned remote version; see ../CLAUDE.md
```

- Run the script with exactly the arguments the task needs. Pass `--coverage` only when the user asked for coverage.
- If the script reports xcbeautify missing, run `scripts/install-tools.sh`, then rerun the same build command.
- Report the script's output as it is. Do not open the log file or the `.xcresult` bundle to investigate.

The raw commands below are for developers working in a terminal:

Run tests per library package (there is no root package that aggregates them):

```bash
cd libraries/ApoorvaUtilities && swift test
swift test --filter BoolExtensionTests                 # one suite (type name)
swift test --filter "BoolExtensionTests/<testName>"   # one test
```

CI (`.github/workflows/ci.yml`) runs every `libraries/*` package that has a `Tests/` folder on an iOS simulator, then uploads coverage to SonarCloud:

```bash
cd libraries/<Module> && xcodebuild test -scheme <Module> \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -skipPackagePluginValidation -skipMacroValidation
```

Packages that depend on Firebase (`ApoorvaServices` and everything above it) need iOS/`xcodebuild`, and may not build with plain macOS `swift test`.

For the app: `skip test` runs parity tests (Swift + transpiled Kotlin). The "Apoorva App" Xcode target builds iOS and deploys the APK to a running Android emulator.

## Conventions

- Tests use a mix of Swift Testing (`import Testing`) and XCTest; match the style already in the file or module you are editing. Date/number formatting tests must not depend on the machine locale.
- Swift 6 tools / strict concurrency: `@MainActor`, `Sendable`, `async/await` throughout.
- Never edit generated Kotlin or anything under `.build/`. Hand-written Kotlin lives only in `app/Android/app/src/main/kotlin/` and `app/Sources/Apoorva/Skip/`.
- Do not write files via Bash (`cat >`, heredocs) or run `git merge`/`gh pr merge` — repo hooks block these. Use the Write/Edit tools for files; merges and PR merges are done by the user.

## Docs

`docs/01` through `docs/12` cover product vision, requirements, architecture (HLD), UI design, feature flags, observability, CI/CD, security, multi-tenancy, NFRs, and the Firestore data model. Check the relevant numbered doc before making product or architecture decisions.

`docs/decisions/` is a separate, dated log of exploration findings and decisions (one file per topic) — check it before re-exploring something that may already have been researched. A `Stop` hook enforces writing an entry there whenever a session explored code or exited plan mode.
