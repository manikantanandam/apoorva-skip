# ApoorvaModels

Pure data models. `Codable` and `SQLCodable`. No persistence or networking here.

## Depends on
- `ApoorvaUtilities`

## Layout
- `Sources/ApoorvaModels/` grouped by domain:
  - `Sale/` — `Sale`, `SaleItem`
  - `POS/` — `PosCart`, `CartItem`
  - `Inventory/` — `InventoryItem`, `CategoryAnalytics`
  - `Cashflow/` — `CashflowTransaction`, `CashflowCategory`, `CashflowSubCategory`
  - `Account/` — `Account`, `InternalTransfer`
  - `Customer/` — `Customer`
  - `DailyCashflowSummary/` — `DailyCashflowSummary`
  - `Organization/` — `Organization`, `OrganizationSnapshot`
  - `User/` — `AppUser`, `AppUserRole`
- `Tests/ApoorvaModelsTests/`

## Rules
- Models stay plain value types. Database mapping goes in `ApoorvaOfflineStorage` (`+GRDB`, `+SkipSQL`).
- Firestore mapping goes in `ApoorvaServices`.

## Commands
```bash
swift test
```
