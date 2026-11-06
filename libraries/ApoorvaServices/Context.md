# ApoorvaServices

Remote access: Firebase Auth and Firestore, called directly through `firebase-ios-sdk` (12.15.0, exact).

## Depends on
- `ApoorvaModels`
- Firebase: `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`

## Layout
- `FirestoreSyncService.swift` — background sync from local storage to Firestore.
- `FirebaseCollectionName.swift` — Firestore collection names. Use these constants, not string literals.
- Per-entity services: `SaleService`, `CashflowTransactionService`, `DailyCashflowSummaryService`, `OrganizationService`, `InventoryItem/InventoryItemService`, `Customer/CustomerService`, `UserService/UserService`.
- `AuthService/AuthService.swift` — sign-in and sign-out.

## Rules
- Prefer calling services through `ApoorvaRepository`. Modules should not call them directly.
- Needs iOS and `xcodebuild`. Plain macOS `swift test` may fail to build because of Firebase.

## Commands
```bash
cd libraries/ApoorvaServices && xcodebuild test -scheme ApoorvaServices \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -skipPackagePluginValidation -skipMacroValidation
```
