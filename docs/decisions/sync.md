# Sync status screen and delta-sync fixes

**Date:** 2026-11-25
**Context:** The Sync status route (Home sync chip → `GlobalRoute.sync`) was a placeholder, and today's data (day balances, other devices' entries) wasn't showing up.

## Exploration
- `SyncEngine` (`ApoorvaRepository/Sync/SyncEngine.swift`) already tracks per-collection `SyncStatus` in memory; `AppCoordinator.syncAll` runs it on `.ready` and on foreground (`MainView` scenePhase). Home pull-to-refresh only reloaded the local cache.
- **Root cause:** `DailyCashflowSummary.updatedAt` is a `TimeInterval`, so Firestore stores it as a number. The delta query used `.greaterThan(field:date:)` (a `Timestamp` filter). Firestore never matches across types, so after the first full sync no new day summary was ever downloaded. The test mock accepted `Date` values, which hid this.
- `DailyCashflowSummaryRepository.saveDailyCashflowSummary` skipped the local write ("let sync handle it"), so a new day only appeared through that broken delta.
- Cursors: Cashflow, Held bills and Daily summaries skipped `SyncCursor.overlap` (other repos use it); Daily summaries advanced the cursor with the device's `Date.now`.
- Sync cursors are keyed by table name only, but `AppCoordinator.recompute` already calls `resetAllSyncStates()` on org switch, so that is fine.
- There is no outbox: writes go through the Firestore SDK's own offline queue, so the screen doesn't show a pending-writes count.

## Decision
- New `StoreCondition.greaterThanNumber(field:value:)`; Daily summary delta uses it. Kept the stored field as a number (changing the model to `Date` would break decoding existing docs).
- Daily summary: cursor = newest record's `updatedAt`, read with the overlap window; save also caches locally.
- Cashflow and Held bills delta reads use `SyncCursor.queryStart` (10 min overlap).
- `SyncEngine.syncAll` shares one in-flight pass between overlapping callers; a forced call waits, then runs its own pass. Exposes `isSyncing`.
- `SyncStatusView`/`SyncStatusViewModel` (`ApoorvaModules/Sync/`): overall badge, last sync, per-collection rows (failures first), Sync now, Re-download all (force, with confirmation). It syncs through `AppCoordinator.syncAll` via `ModulesContainer.makeSyncStatusViewModel`, so Home reloads after.
- Home pull-to-refresh now runs `syncAll` first; the sync chip refreshes after every pass and shows "Syncing".

## Why
- Routing manual syncs through the coordinator keeps `syncGeneration`/Home reload and org-phase recompute in one place.
- Statuses stay in memory (not persisted): after a cold launch the first pass fills them within seconds.
- Deferred: pending-writes count (needs Firestore `hasPendingWrites` plumbing), backoff/periodic sync (`sync.interval_sec`).

## Update 2026-11-27: pending-writes count + periodic/backoff sync

**Context:** Picked up both items deferred above.

### Pending-writes count
- No outbox exists, so there's no stored "dirty" flag per record. Firestore's SDK already tracks `hasPendingWrites` per document in its own offline write cache — used that instead of building one.
- `FirestoreStoring.pendingWriteCount(collection:)`: one-shot snapshot listener, counts `metadata.hasPendingWrites`, removes itself on the first callback. Point-in-time only, not persisted — computed on demand (Sync status screen load/manual sync), never during periodic/background `syncAll` passes, so that loop stays cheap.
- New `PendingWritesReporting` protocol. `OrgCollectionRepository<Document>` conforms directly (covers the ~14 collections on the generic path via `OrgCollectionService.pendingWriteCount(orgId:)`). The 6 hand-rolled collections (inventory, customers, sales, heldBills, cashflow, dailyCashflowSummaries) each got their own `pendingWriteCount()` on the repository protocol (default `0` so other fakes/conformers don't break) delegating to a matching addition on their service protocol, and `SyncAdapter` grew an optional `pendingWrites` closure to carry it into the engine.
- `SyncEngine.pendingWriteCounts()` aggregates by `syncKey`; `SyncStatusViewModel`/`View` show the total as "N changes waiting to upload".

### Periodic/backoff sync
- Added the `sync.interval_sec` flag for real: `FeatureFlag.syncIntervalSec` (kind `.number`, default 30) + `AppConfig.number(_:)` (no number-kind flag existed before this).
- `AppCoordinator` runs a cancellable loop while `.ready`: sleeps `backoffDelay(base:failures:)` (pure, testable — doubles per consecutive failed pass, capped at 300s, resets on a clean pass), then calls the existing `syncAll()`. Started on entering `.ready`, stopped on leaving it, paused/resumed with scene-phase backgrounding from `MainView` (separate from the existing one-shot foreground sync).

### Why
- Reused the Firestore SDK's own pending-write tracking instead of an outbox — much less surface area, and accurate per the SDK's own offline queue.
- Kept pending-write computation out of the hot sync path so periodic/background syncs don't open extra listeners on every pass.
- `backoffDelay` is a pure `nonisolated static func` specifically so it's unit-testable without spinning up `AppCoordinator`'s full container graph.

### Fix same day: Sync status screen stuck "Syncing" at "Day closes"
**Symptom:** Overall status and the "Day closes" row stayed on "Syncing" forever.
**Root cause:** `pendingWriteCount(collection:)` was first implemented with a live `addSnapshotListener`, resumed once from inside its own callback. `SyncEngine.pendingWriteCounts()`/`SyncEngine.runAll()` both walk every registered collection sequentially — if a listener never gets its first callback (e.g. offline with nothing cached yet for that path), the `await` never returns and blocks every collection queued behind it in the same pass, which is exactly what "stuck at Day closes" looked like.
**Fix:** Swapped to a one-shot cache-only read — `Query.getDocuments(source: .cache)` — which never waits on the network and can't hang; confirmed `FirestoreSource.cache` and `SnapshotMetadata.hasPendingWrites` exist in the checked-out `skip-firebase` source before making the change.

### Same day: made a future hang like this observable for real users
**Why:** Checked what `SyncEngine` already reports (`AnalyticsEvent.syncCompleted`/`.syncFailed`, `CrashReportingServicing.recordNonFatal`, `PerformanceMonitoringServicing.measure`) — all three only fire on normal return or a caught `throw`. A hang does neither: `measure`'s trace-stopping `defer` never runs, nothing throws for Crashlytics to catch, and `syncCompleted`/`syncFailed` never fire. The bug above would have been completely silent in production; we only found it because the user was watching the screen live.
**Decision:** `SyncEngine` now races every `sync(force:)` and `pendingWriteCount()` call against a deadline (`timeoutSeconds`, default 45s) using `withThrowingTaskGroup`, via a new `SyncTimeoutError`. A timeout now behaves like any other failure — `recordNonFatal(context: "sync.<key>")`/`"pendingWriteCount.<key>"` fires, and `sync(force:)` timeouts additionally log a new `AnalyticsEvent.syncTimedOut(collection:afterSeconds:)` (distinct from `.syncFailed` so dashboards can tell "it broke" apart from "it hung"). `pendingWriteCounts()` treats a timed-out collection as `0` and keeps going instead of stalling every collection queued behind it.
