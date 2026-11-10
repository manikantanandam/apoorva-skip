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
