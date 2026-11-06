# ApoorvaModules

Feature SwiftUI views and `@Observable` view models. Every feature lives in its own folder.

## Depends on
- `ApoorvaRepository`, `ApoorvaUtilities`

## Features
- `POS/` — `POSView`, `POSViewModel`, `QuickItemsView`, `SelectedCartItemsView`
- `Cashflow/` — `CashflowView`, `CashflowViewModel`, `AddUpdateCashflowTransactionView` and its view model
- `DailyCashflowSummary/` — summary, list, and add/update screens with their view models
- `Inventory/` — `InventoryView`, `InventoryViewModel`
- `Customers/` — `CustomersView`, `CustomersViewModel`
- `Sale/` — `SaleListView`, `SaleViewModel`
- `Login/` — `LoginView`, `LoginViewModel`
- `Profile/` — `ProfileView`, `ProfileViewModel`

## Shared
- `Components/` — reusable views: buttons, text fields, cards, labels, avatars, grids, loaders, and selection views.
- `Resources/` — `ApoorvaColor`, `Icons`.

## Rules
- View models are `@MainActor` and `@Observable`. They take repositories through their initializer.
- Views do not reach into storage or services.
- Put reusable UI in `Components/`, not inside a feature folder.

## Commands
```bash
cd libraries/ApoorvaModules && xcodebuild test -scheme ApoorvaModules \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -skipPackagePluginValidation -skipMacroValidation
```
