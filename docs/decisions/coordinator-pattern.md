# Coordinator pattern: keep route-state design over MVVM-C factory style

**Date:** 2026-11-10
**Context:** Discussion of whether to keep the existing SwiftUI Coordinator pattern in `ApoorvaAppCore/Router/Coordinators/*` or move to a classic MVVM-C variant where the Coordinator builds the View+ViewModel pair and returns the View.

## Exploration
- Each feature Coordinator (`AppCoordinator.swift`, `HomeCoordinator.swift`, `HomeTabsCoordinator.swift`, etc.) is an `@Observable @MainActor` class holding only route state — `path: [Route]`, `presentedSheet: Route?` — never a reference to a View or ViewModel instance.
- Views own their own ViewModel via the DI container (e.g. `HomeCoordinatorView.swift` builds `HomeViewModel` through `container.makeHomeViewModel(...)`), and only read/mutate the injected Coordinator for navigation state.
- No ViewModel holds a reference back to any Coordinator; navigation is triggered via callbacks passed from the View into its action handlers.
- One weak parent→child back-reference exists (`HomeTabsCoordinator.swift`: `weak var appCoordinator`), scoped to parent-child only.

## Decision
- Keep the current route-state-only Coordinator design. Do not introduce a Coordinator-as-factory pattern (Coordinator constructs and returns the View+ViewModel pair).

## Why
- The route-state design fits SwiftUI's declarative/value-type model better than a factory-style Coordinator that owns and returns Views.
- It avoids the classic VM→Coordinator back-reference problem entirely.
- It avoids the Coordinator becoming a god-object that owns the whole screen's object graph, which a factory-style Coordinator tends toward.
