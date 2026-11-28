# ApoorvaFeatureFlags

The single isolated home for everything flag-related: the `FeatureFlag` catalogue and the Remote
Config sync layer that resolves it. Other modules import this one package to read a flag — no
need to touch `ApoorvaServices` or know Firebase is involved.

## Depends on
- `ApoorvaModels` — only for `AppVersion` (used by `VersionGateValue.isOn`)
- `ManiLogger`
- `skip-firebase` (`SkipFirebaseCore`, `SkipFirebaseRemoteConfig`)

## Layout
- `Sources/ApoorvaFeatureFlags/`:
  - `FeatureFlags.swift` — the `FeatureFlag` catalogue (docs/05), `FlagSource`/`FlagResolution`, and
    `FlagResolver` (pure App→Org→Store→Role resolution).
  - `RemoteConfigCatalog.swift` — `RemoteConfigKeyDefinition`/`RemoteConfigCatalog.all`, a pure
    mapping over `FeatureFlag.allCases`; `VersionGateValue`.
  - `RemoteConfigServicing.swift` — provider-agnostic protocol (mirrors `AnalyticsServicing` etc. in
    `ApoorvaServices`), plus `RemoteConfigDefaultValue`.
  - `AppConfig.swift` — the one typed read path, keyed by `FeatureFlag`.
  - `FirebaseRemoteConfigService.swift` / `NoOpRemoteConfigService.swift` / `FakeRemoteConfigService.swift`
    — the Firebase, preview/unit-test, and `-UITesting` implementations.
  - `RemoteConfigCatalogDefaults.swift` — builds Firebase's compiled defaults, grouping dot-namespaced
    (and standalone-module) bool flags into one JSON parameter per namespace, since Remote Config
    parameter keys can't contain dots (see `docs/decisions/remote-config.md`).
  - `RemoteConfigLogFormatter.swift` — pure post-fetch log-line formatting.
- `Tests/ApoorvaFeatureFlagsTests/`

## Rules
- Consumers read flags through `AppSession.isOn(_:)`/`access(_:)` (bool) or `AppConfig` (non-bool),
  never `RemoteConfigServicing` directly — except the Developer Settings "Feature flags" screen
  (`FlagOverridesViewModel` in `ApoorvaModules`), which is the one sanctioned exception.
- `DebugRemoteConfigOverrideService` (debug-only local overrides) lives in `ApoorvaAppCore`, not
  here, since it also needs `ApoorvaEnvironment`'s `DeveloperToolsProtocol`.
- No singletons; the app container builds and owns one `AppConfig`/`RemoteConfigServicing`.

## Commands
```bash
scripts/build.sh ApoorvaFeatureFlags test
```
