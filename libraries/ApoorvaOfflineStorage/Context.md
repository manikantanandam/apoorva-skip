# ApoorvaOfflineStorage

Local database layer. SQLite is the source of truth for the app.

## Depends on
- `ApoorvaModels`, `ApoorvaUtilities`
- skip-sql 0.16.1 (exact)

## Backends
- `SkipSQL/` — **wired into the app today.**
  - `SkipSqlDatabaseManager` opens the database.
  - `Storage/` holds one `*LocalStorage` per entity, plus `SyncStorage`.
  - `Model/` holds `+SkipSQL` mappings and `SyncState`.
- A GRDB backend existed but was never wired in; it was removed (see git history) to keep coverage meaningful.

## Other folders
- `protocols/` — storage protocols the repositories depend on (e.g. `InventoryItemLocalStorageProtocol`, `SaleStorageProtocol`). Add a protocol here before adding a new storage type.
- `UserDefaults/UserDefaultsStorage.swift` — small key-value storage.

## Rules
- Repositories and view models talk to the protocols, not to a backend directly.
- Each entity needs a protocol, a SkipSQL storage, and a model mapping.

## Clearing data
- `SQLContext` (from the `skip-sql` package) exposes `deleteAll<T: SQLCodable>(_:inSchema:)` — deletes all rows of one table without touching the file or the open connection. `SyncStorage.resetAllSyncStates()` uses this for `SyncState`; `SkipSqlDatabase.clearAllLocalData()` extends it to every table (useful on logout).
- No individual `*LocalStorage` class has a bulk clear/truncate method — only per-id `delete`/`markAsDeleted`.
- Deleting the SQLite file on disk while the app keeps running is unsafe: the already-open `SQLContext` connection doesn't tolerate its backing file being unlinked. That's why the dev-tools "clear database" action (`DeveloperSettingsViewModel`) pairs file deletion with `exit(0)`. For a same-session clear, use in-place `deleteAll`/`DELETE FROM`, never file deletion.
- `UserDefaultsStorageProtocol.removeAll(matchingPrefix:)` is the scoped way to clear a group of keys (e.g. all `"user_*"` cache entries) — prefer it over `UserDefaults.standard.removePersistentDomain(forName:)`, which wipes the entire app's UserDefaults domain, not just one storage's keys.

## Commands
```bash
swift test
```
