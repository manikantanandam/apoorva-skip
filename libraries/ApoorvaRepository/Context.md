# ApoorvaRepository

Offline-first coordination. Writes go to local storage first. Sync to remote happens in the background.

## Depends on
- `ApoorvaOfflineStorage`, `ApoorvaServices`

## Layout
One repository per domain:
- `SalesRepository`
- `CashflowRepository`
- `DailyCashflowSummaryRepository`
- `InventoryItemRepository`
- `CustomerRepository`
- `OrganizationRepository`
- `UserRepository`

## Rules
- Read from local storage. Never make the UI wait on a network call.
- Write locally first. Sync to Firestore runs afterwards via `SyncStorage` and `FirestoreSyncService`.
- Modules depend on these repositories, not on storage or services.

## Commands
Needs iOS and `xcodebuild`, because it depends on Firebase through `ApoorvaServices`.
```bash
cd libraries/ApoorvaRepository && xcodebuild test -scheme ApoorvaRepository \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -skipPackagePluginValidation -skipMacroValidation
```
