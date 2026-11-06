# ApoorvaUtilities

Foundation-only helpers shared by every other package. No dependencies.

## Layout
- `Sources/ApoorvaUtilities/` — extensions on `Array`, `Dictionary`, `Bool`, `Int`, `Int64`, `Double`, `String`, `Date`, plus `SortType`.
- `Tests/ApoorvaUtilitiesTests/` — one test file per extension.

## Rules
- Date and number formatting must not depend on the machine locale. Tests must pin locale and time zone.
- Keep this package free of domain types. Those belong in `ApoorvaModels`.

## Commands
```bash
swift test
swift test --filter DateExtensionTests
```
