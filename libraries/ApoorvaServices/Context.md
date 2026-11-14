# ApoorvaServices

Remote access: Firebase Auth and Firestore, called directly through `firebase-ios-sdk` (12.15.0, exact).

## Depends on
- `ApoorvaModels`
- Firebase: `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`

## Layout
- Firebase-facing services (`AuthService`, `Firebase*Service`) delegate to small internal backend protocols (`AuthBackend`, `RemoteConfigBackend`, `AnalyticsBackend`, `CrashlyticsBackend`, `PerformanceTraceBackend`); only the `Firebase*Backend` adapters at the bottom of each file touch the SDK, so tests mock the backend.
- `FirebaseCollectionName.swift` — Firestore collection names. Use these constants, not string literals.
- Per-entity services: `SaleService`, `CashflowTransactionService`, `DailyCashflowSummaryService`, `OrganizationService`, `InventoryItem/InventoryItemService`, `Customer/CustomerService`, `UserService/UserService`.
- `AuthService/AuthService.swift` — sign-in and sign-out.

## Rules
- Prefer calling services through `ApoorvaRepository`. Modules should not call them directly.
- Needs iOS and `xcodebuild`. Plain macOS `swift test` may fail to build because of Firebase.

## Firestore query seam
- `FirestoreStoring`/`StoreCondition` (`Firestore/FirestoreStoring.swift`) is a deliberately narrow query abstraction: `.greaterThan(field:date:)`, `.isIn(field:values:)`, `.arrayContains(field:value:)`. Add new cases here (and to any test double's matching switch) rather than reaching for raw `Filter`/`Query` elsewhere.
- There is no org→users reverse lookup modeled in Firestore data — only user→orgs via `AppUser.assignedOrgs`. `UserService.listUsers(orgId:)` filters on a denormalized `assignedOrgIds: [String]` field written onto `users/{uid}` docs for exactly this; existing docs provisioned outside this app may not have that field yet, so the query can silently return nothing for a pre-existing org until it's backfilled. `UserService.updateRole(userId:role:)` is the matching admin write, alongside `updateSelectedOrganization`.

## Commands
```bash
cd libraries/ApoorvaServices && xcodebuild test -scheme ApoorvaServices \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -skipPackagePluginValidation -skipMacroValidation
```
