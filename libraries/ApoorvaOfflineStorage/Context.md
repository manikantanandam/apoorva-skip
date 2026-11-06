# ApoorvaOfflineStorage

Local database layer. SQLite is the source of truth for the app.

## Depends on
- `ApoorvaModels`, `ApoorvaUtilities`
- GRDB.swift 7.11.1 (exact), skip-sql 0.16.1 (exact)

## Backends
- `SkipSQL/` — **wired into the app today.**
  - `SkipSqlDatabaseManager` opens the database.
  - `Storage/` holds one `*LocalStorage` per entity, plus `SyncStorage`.
  - `Model/` holds `+SkipSQL` mappings and `SyncState`.
- `GRDB/` — **not wired.** Contains `AppDatabase`, `DatabaseMigratable`, `AppDatabase+Operations`, and `Model/` (`+GRDB` mappings).

## Other folders
- `protocols/` — storage protocols the repositories depend on (e.g. `InventoryItemLocalStorageProtocol`, `SaleStorageProtocol`). Add a protocol here before adding a new storage type.
- `UserDefaults/UserDefaultsStorage.swift` — small key-value storage.

## Rules
- Repositories and view models talk to the protocols, not to a backend directly.
- Each entity needs a protocol, a SkipSQL storage, and a model mapping.

## Commands
```bash
swift test
```
