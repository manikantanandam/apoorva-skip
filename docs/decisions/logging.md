# Logging

**Date:** 2026-11-13
**Context:** The Developer Settings Logs screen existed but nothing wrote to its `LogBuffer`; ~130 ad-hoc `print()` calls were scattered across modules (a few dumped account names/balances). Goal: one logger feeding the Xcode console and the Logs screen, plus a plan for remote extraction (bug fixing, user journey, cost).

## Exploration
- `LogBuffer` lived in `ApoorvaEnvironment/DeveloperTools.swift`; only `DeveloperSettingsViewModel` read it. Nothing appended.
- `ApoorvaEnvironment` isn't a dependency of Services/Repository/OfflineStorage; `ApoorvaUtilities` is the remote versioned library (a change means a release cycle).
- `CrashReportingServicing.log(_:)` already existed but had no callers.
- `docs/06` §4 already specified `os.Logger` categories, levels and the no-PII rule.

## Decision
- New local zero-dependency package `libraries/ApoorvaLogging` at the bottom of the graph: `AppLogger`, `LogEntry`/`LogLevel`/`LogCategory`, `LogSink`, `LogSinks` registry, `LogBuffer` (moved here), `FileLogSink`.
- **Singleton exception:** `LogSinks.shared` is a process-wide registry. Logging is cross-cutting, like `os.Logger`; injecting a logger into every type would touch every initializer. Sinks are still built and registered by `AppContainer`.
- Call sites use a file-scope `private let logger = AppLogger(category:)`, not a static on the type, because some types are generic or actors.
- `CrashReportingLogSink` lives in AppCore so Firebase stays out of `ApoorvaLogging`. It forwards warning+ only.
- `ApoorvaEnvironment` gained `platforms: iOS 17 / macOS 14` because it now depends on `ApoorvaLogging`.
- `app/Darwin/Sources/Main.swift` keeps its single `print` because the Xcode app target doesn't link `ApoorvaLogging` directly.
- Remote extraction is phased (see `docs/06` §4): Phase 2 on-demand gzip upload to Firebase Storage gated by Remote Config; Phase 3 journey events to BigQuery and an aggregated daily `firestore_usage` event for cost.

## 2026-11-13 update — Logs screen filters
- Added category chips (multi-select; empty = all; each shows a count), time range (5 min / 15 min / 1 hour / All), search highlighting, an "N of M" result count and a Reset button.
- Category counts ignore the category selection but respect level, time and search, so each chip shows what selecting it would add.
- The screen still reads only the in-memory buffer for the current session. Reading the log file for earlier sessions was deferred because it adds parsing and a session filter.
- The view model takes `now: () -> Date` so time-range tests are deterministic.
- List rows show at most 5 lines of the message, so long entries such as a future dump of every Remote Config flag stay short. Tapping a row opens `LogDetailView`, which shows the full message (selectable), the metadata, and Share/Copy buttons. It uses an inline `NavigationLink`, like the other developer tools, not a coordinator route.

## Why
- A bottom-of-graph package lets every module log without a release of the remote utilities library.
- File sink now = Phase 2 upload only needs a gzip + Storage upload step, no logging changes.
- Firestore was rejected as a log store because it bills per document write, which works against the cost goal.
