# ApoorvaModules

Feature SwiftUI views and `@Observable` view models. Every feature lives in its own folder.

## Depends on
- `ApoorvaRepository`, `ApoorvaUtilities`
- `ManiSwiftUIComponents` (remote SPM package, pinned `exact: "1.0.0"`) — themeable `Mani*` SwiftUI component library. Its own component/token/theming reference lives in `context.md` inside its SPM checkout (e.g. `~/Library/Developer/Xcode/DerivedData/ApoorvaModules-*/SourcePackages/checkouts/ManiSwiftUIComponents/context.md`), not a README — read that file directly instead of grepping its component sources.

## Features
- `POS/` — `POSView`, `POSViewModel`, `QuickItemsView`, `SelectedCartItemsView`
- `Cashflow/` — `CashflowView`, `CashflowViewModel`, `AddUpdateCashflowTransactionView` and its view model
- `DailyCashflowSummary/` — summary, list, and add/update screens with their view models
- `Inventory/` — `InventoryView`, `InventoryViewModel`
- `Customers/` — `CustomersView`, `CustomersViewModel`
- `Sale/` — `SaleListView`, `SaleViewModel`
- `Login/` — `LoginView`, `LoginViewModel`
- `Profile/` — `ProfileView`, `ProfileViewModel`
- `User/` — `UserListView`, `UserListViewModel`, `UserRoleEditorView` (admin-only: list org members, change role)
- `Organization/` — `OrganizationListView`, `OrganizationListViewModel` (switch between the current user's assigned organizations)

## Shared
- `Components/` — reusable views: buttons, text fields, cards, labels, avatars, grids, loaders, and selection views.
- `Resources/` — `ApoorvaColor`, `Icons`.

## Rules
- View models are `@MainActor` and `@Observable`. They take repositories through their initializer.
- Views do not reach into storage or services.
- Put reusable UI in `Components/`, not inside a feature folder.
- New screens should be built from `ManiSwiftUIComponents` (`Mani*` types), not `Components/` — `Components/` holds the legacy pre-Mani UI kit and is not the design-system target for new work.

## Commands
```bash
cd libraries/ApoorvaModules && xcodebuild test -scheme ApoorvaModules \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -skipPackagePluginValidation -skipMacroValidation
```
