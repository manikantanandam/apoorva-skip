# ApoorvaAppCore

Composition root. Builds the object graph and holds the root navigation.

## Depends on
- `ApoorvaModules` (and transitively everything below it)

## Layout
- `Containers/` — lazy containers, one per layer, all built by `AppContainer`:
  - `ServicesContainer`
  - `OfflineStorageContainer`
  - `RepositoryContainer`
  - `ModulesContainer`
- `Router/Route.swift` — app routes.
- `MainView.swift`, `HomeView.swift` — root views.

## Rules
- No singletons. Create new dependencies in the matching container, then inject them downward.
- Only this package wires layers together. Other packages receive dependencies through their initializers.

## Commands
Needs iOS and `xcodebuild`. This package has no `Tests/` folder.
