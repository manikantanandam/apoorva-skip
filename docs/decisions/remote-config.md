# Firebase Remote Config: standalone service, feeds FlagResolver's app layer, local-only dev overrides

**Date:** 2026-11-10
**Context:** `docs/05-feature-flags-and-config.md` specifies the app level of the flag precedence chain (App → Org → Store → Role) should come from Firebase Remote Config. No Remote Config integration existed yet; `docs/07-build-ci-cd.md` §7a already listed "Remote Config fetch now" as a planned developer tool.

## Exploration
- The only built app-level config service, `PlatformConfigService` (`ApoorvaServices/Platform/`), deliberately uses Firestore instead of Remote Config ("so the Apoorva console can edit it") — it is not a Remote Config implementation and isn't being replaced.
- `AppSession.resolution(of:)` (`ApoorvaModules/Session/AppSession.swift`) already called `FlagResolver.resolve(_:app:...)` with `app: platform.flags` (Firestore), so the "app" layer existed but had no Remote Config source wired in.
- The local-override pattern already exists end-to-end for flags: `DeveloperTools`/`DeveloperToolsProtocol` (UserDefaults-backed, `ApoorvaEnvironment`) → `DeveloperSettingsViewModel` → `FlagOverridesView`, gated by `#if DEBUG` in `AppContainer`.
- `ServicesContainer`/`AppContainer` use plain one-line lazy composition with no DI framework; cross-cutting debug behavior (like developer overrides) is composed at the `AppContainer` level, not inside the services themselves.

## Decision
- Added `RemoteConfigServicing` as a standalone, provider-agnostic protocol (`ApoorvaServices/RemoteConfig/`), with `FirebaseRemoteConfigService` and `NoOpRemoteConfigService` implementations — mirrors the existing `AnalyticsServicing`/`FirebaseAnalyticsService` shape so the concrete provider can be swapped without touching call sites.
- `AppSession.resolution(of:)` now overlays the requested flag's Remote Config value onto `platform.flags` before calling `FlagResolver.resolve`, making Remote Config authoritative for the flag catalogue specifically, without discarding other Firestore-set app flags or replacing `PlatformConfigService`'s broader role (min app version, sign-in methods, plan limits).
- Remote Config's compiled defaults are generated from the existing `FeatureFlag` catalogue (`FeatureFlagRemoteConfigDefaults.make()`) instead of duplicating the flag list.
- Local dev overrides for Remote Config live in `DeveloperTools.remoteConfigOverrides: [String: String]` (new, mirrors `flagOverrides` exactly) — local-only, never synced, debug-build only.
- `DebugRemoteConfigOverrideService` (new, lives in `ApoorvaAppCore` since it needs both `ApoorvaServices` and `ApoorvaEnvironment` types) decorates the real service with those overrides; composed only under `#if DEBUG` in `AppContainer.resolvedRemoteConfigService`, same gating pattern as `makeDeveloperSettingsViewModel()`.
- Dev UI extends the existing `FlagOverridesView`/`DeveloperSettingsViewModel` with a "Remote Config overrides" section and a "Fetch now" button, rather than a new standalone screen.

## Why
- Keeps Remote Config swappable/testable (closed `RemoteConfigDefaultValue` enum, no Firebase types leak into the public protocol) while still satisfying doc 05's intent that the app layer comes from Remote Config.
- Avoids relitigating or duplicating `PlatformConfigService`'s Firestore-based role.
- Reuses the existing `DeveloperTools`/`AppContainer` debug-override composition pattern instead of inventing a new one.

## Update 2026-11-11: catalogue-driven Developer Settings display

**Problem found:** the freeform "add any key/value as an override" UI above meant that creating a new parameter in the Firebase console (e.g. `min_app_version`) never showed up in Developer Settings — that screen only ever listed overrides a developer had manually typed in, never the actual set of keys the app knows about or their live remote values. There was also no single local source of truth for "what keys does the app expect" to create the console parameter against.

**Decision:**
- Added `RemoteConfigCatalog` (`ApoorvaModels/Access/RemoteConfigCatalog.swift`): the single local list of every Remote Config key the app knows about, each with a `kind` (`bool`/`string`/`number`) and compiled default. It's `FeatureFlag.allCases` (bool, already resolvable via `FlagResolver`) plus `nonFlagKeys` — app-level-only values that skip the org/store/role hierarchy entirely, matching docs/05's own catalogue table where some rows are explicitly "App only". `min_app_version` (string) was added here as the first non-boolean example.
- Workflow going forward: declare the key in `RemoteConfigCatalog` first, then create the matching parameter (same key, same type) in the Firebase console. `RemoteConfigCatalogDefaults.make()` (renamed from `FeatureFlagRemoteConfigDefaults`) seeds Remote Config's compiled defaults from this catalogue, so the app is safe even before the console parameter exists.
- `DeveloperSettingsViewModel.remoteConfigRows` now builds one row per catalogue entry showing the live remote value and, if a local override is set, the override value with `isOverridden == true` — `FlagOverridesView` renders an "Overridden" badge and a per-row clear action. The freeform add-any-key UI was removed.
- `DeveloperSettingsViewModel` now reads the *undecorated* `servicesContainer.remoteConfigService` (not the `DebugRemoteConfigOverrideService`-wrapped one) so it can show the true remote value separately from any override — `AppSession`/production app behavior is untouched and still reads through the override-aware decorator.
- **Explicitly out of scope:** `min_app_version`'s actual consumer (`SessionPhase.forceUpdate`) still reads Firestore `PlatformConfig.minAppVersion`, not this new Remote Config key. Repointing that consumer at Remote Config is a separate follow-up. Other docs/05 "App only" numeric keys (`sync.batch_size`, `plan.trial_days`, etc.) weren't added to the catalogue since nothing reads them from Remote Config yet — add them the same way when needed.

## Update 2026-11-11 (later): `FeatureFlag` is the sole source of truth; added object-shaped (version-gate) flags

**Decision:**
- `RemoteConfigCatalog.nonFlagKeys` was removed. `min_app_version` moved into `FeatureFlag` itself (`case minAppVersion = "min_app_version"`), which now carries a `kind` (`bool`/`string`/`number`/`versionGate`) and per-kind compiled defaults (`defaultValue` for bool, `defaultStringValue`, `defaultNumberValue`, `defaultVersionGateValue`). `RemoteConfigCatalog.all` is now a pure mapping: `FeatureFlag.allCases.map(RemoteConfigKeyDefinition.init(flag:))` — one source of truth, no duplicated declarations.
- `isAppOnly` is now `kind != .bool || <existing auth./kill. prefix check>`: any non-bool flag is automatically app-only, which keeps `AdminHomeView.featuresOn` (`FeatureFlag.allCases.filter { !$0.isAppOnly && session.isOn($0) }`) safe — `session.isOn`/`FlagResolver` is bool-only and must never be called for a non-bool flag. A regression test (`everyNonBoolFlagIsAppOnly`) guards this invariant.
- Added a 4th value kind, `versionGate`, for features gated by app version rather than a flat bool: `VersionGateValue { enabled: Bool, minVersion: String? }`, with `isOn(currentAppVersion:)` reusing the existing `AppVersion` comparator (`ApoorvaModels/Session/SessionPhase.swift`). Scope: app-level only, same as `min_app_version` — no org/store/role layering.
- `RemoteConfigServicing` gained `jsonValue<T: Decodable>(forKey:as:)` and `RemoteConfigDefaultValue` gained `.json(Data)`, so any future object-shaped kind can reuse the same fetch/default/override plumbing (`FirebaseRemoteConfigService`, `NoOpRemoteConfigService`, `DebugRemoteConfigOverrideService`) just by adding a new `RemoteConfigValueKind` case and a Codable value type — not specific to version gates.
- No concrete version-gated `FeatureFlag` case exists yet (nothing named a real feature needing it) — the mechanism is fully built and tested (`VersionGateValueTests`, `RemoteConfigJSONRoundTripTests`, `DebugRemoteConfigOverrideServiceTests.json*`, `DeveloperSettingsViewModelTests.versionGateOverrideRoundTrips`) so adding a real one is a one-line addition to `FeatureFlag`.

## Update 2026-11-13: `AppConfig` is the single typed read path

- `AppConfig` (`ApoorvaServices/RemoteConfig`) wraps the override-aware `RemoteConfigServicing` and is keyed by `FeatureFlag` (`bool(_:)`, `string(_:)`, `minAppVersion`), applying compiled defaults so callers never read raw keys or repeat the fallback.
- One container-owned instance (`AppContainer.appConfig`), injected into `AppSession` (exposed as `session.config`) and `AppCoordinator`; deliberately not a static singleton (repo rule: no singletons).
- Bool flags still go through `session.isOn(_:)`; non-bool flags through `session.config`. `FlagOverridesViewModel` keeps the undecorated service to show remote vs override.

## Update 2026-11-13: fetch logging and launch fetch

- `FirebaseRemoteConfigService.fetchAndActivate` logs (category `config`, info) fetch start, result status + duration, and one line with every catalogue key as `key=value(source)` (source remote/default/static); failures log an error and rethrow. Covers both the launch fetch and Developer "Fetch now". Formatting is in `RemoteConfigLogFormatter` for testability.
- `AppCoordinator` fetches once at launch and recomputes the phase afterwards, so a changed `min_app_version` applies without waiting for another session emission.
- Debug builds create `FirebaseRemoteConfigService(minimumFetchInterval: 0)`; release keeps Firebase's 12h default. Without this, a console change kept returning the cached template (`usingPreFetchedData`) for up to 12 hours.
