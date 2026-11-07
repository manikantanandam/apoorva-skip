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
- `ApoorvaModules` doesn't depend on `ApoorvaOfflineStorage` (see the module dependency graph in the root `CLAUDE.md`), so a Modules-layer view model that needs a cross-cutting local-storage action (clearing the DB, terminating the app) can't reach it through a repository protocol. The established pattern is a plain closure built in a container here and injected through the view model's initializer — see `DeveloperSettingsViewModel`'s `clearLocalDatabase`/`terminateApp` and `ProfileViewModel`'s `clearLocalData`.

## Commands
Needs iOS and `xcodebuild`. This package has no `Tests/` folder.
