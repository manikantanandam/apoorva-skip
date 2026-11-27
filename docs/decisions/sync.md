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
