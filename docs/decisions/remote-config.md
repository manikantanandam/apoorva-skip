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
- The Feature flags screen distinguishes Firebase values from compiled defaults via `RemoteConfigServicing.isRemoteValue(forKey:)` (Firebase `configValue.source == .remote`): rows read `Remote: x` or `Default: x (not in Firebase)`.
- The Feature flags screen only overrides existing flags: the free-text "add flag" field is gone, local rows are one per bool catalogue flag (Default/On/Off), `setFlag`/`setRemoteConfigOverride` ignore unknown keys, and stale invented overrides are pruned on init. New flags are created in `FeatureFlag` and the Firebase console only.

## Update 2026-11-28: dot-namespaced flags grouped into one JSON parameter per namespace

**Problem found:** attempting to create the Firebase console parameters for the `FeatureFlag` catalogue (via `firebase deploy --only remoteconfig`) failed with `400 VALIDATION_ERROR: INVALID_KEY` for `billing.credit_sales` — **Firebase Remote Config parameter keys cannot contain dots**. 25 of 29 `FeatureFlag.rawValue`s are dot-namespaced (`billing.*`, `auth.*`, `plan.*`, `insights.*`, `printing.*`, `inventory.*`, `staff.*`, `offers.*`, `summary.*`, `kill.*`) and could never exist as literal Remote Config parameters as originally coded — the app-level override path for most flags was unreachable.

**Exploration:**
- Firestore (org/store/role/platform flags, `OrgSettings.swift`) has no dot problem — map field keys tolerate dots fine. Only the Remote Config *fetch* layer needed to change; `FlagResolver`, `AppSession`'s Firestore merging, and every `.isOn(...)` call site (`MoreCoordinatorView`, `NewBillCoordinatorView`, `CustomersCoordinatorView`, `MoreMenuView`, `CheckoutViewModel`, `BillsScreens`, `AuthScreens`, `AdminHomeView`) stay untouched.
- The JSON-object plumbing needed already existed, built for the still-unused `versionGate` kind and already generalized: `RemoteConfigServicing.jsonValue<T: Decodable>`, `RemoteConfigDefaultValue.json(Data)`, `DebugRemoteConfigOverrideService.jsonValue` all work for any `Decodable`/`Encodable`, not versionGate-specific. `Dictionary<String, Bool>` is natively `Codable`, so no new value struct was needed.

**Decision:**
- Each dot-prefix namespace shares one Remote Config parameter whose value is a JSON `[String: Bool]` object (e.g. `billing` → `{"credit_sales": true, "returns": true, ...}`), instead of one parameter per flag. No `FeatureFlag.rawValue` was renamed — Firestore-side keys and `FlagResolver` are unaffected.
- `FeatureFlag.remoteConfigGroupKey` / `remoteConfigFieldName` / `remoteConfigParameterKey` (`FeatureFlags.swift`, mirrored on `RemoteConfigKeyDefinition` in `RemoteConfigCatalog.swift`) derive the group/field from the existing rawValue. `RemoteConfigCatalog.all` keeps its 1:1-with-`FeatureFlag` shape (used for display/iteration); only the two places that actually talk to the backed service became group-aware: `AppConfig.bool(_:)` (via a shared `AppConfig.resolveBool` helper) and `FlagOverridesViewModel` (read/override-set/override-clear).
- Overriding one field in Developer Settings necessarily snapshots the whole group (Remote Config overrides replace a key's value wholesale, there's no field-level merge deeper in the stack) — documented as an accepted tradeoff, not fixed, since fixing it would mean changing `DebugRemoteConfigOverrideService`'s generic contract.
- A grouped flag's old flat dotted key (e.g. `billing.hold_bills`) is no longer a valid override storage location; `FlagOverridesViewModel.isKnownRemoteConfigKey` now checks `remoteConfigParameterKey` so such pre-migration entries are pruned on init instead of silently going stale.
- Groups: `billing`, `auth`, `plan`, `insights`, `printing`, `inventory`, `staff`, `offers`, `summary`, `kill` (10 total). Ungrouped (valid keys already, unchanged): `orders`, `suppliers`, `expenses`, `min_app_version`.
- Explicitly out of scope: richer non-bool fields (e.g. a `split_payment_modes: [String]` array) don't fit a uniform `[String: Bool]` value — introduce a dedicated per-group `Codable` struct (like `VersionGateValue`) only when a concrete non-bool field is actually needed.
- Firebase console creation was scoped to `apoorva-debug-8f9eb` only (not `apoorva-4ad68`/`apoorva-production`) per explicit user choice, and is still pending re-deploy with the corrected grouped template — blocked on verifying the code changes build (no iOS Simulator available in this worktree to run `scripts/build.sh`).

## Update 2026-11-28 (later): every bool flag is grouped, not just dot-namespaced ones

**Problem found:** `orders`, `suppliers`, `expenses` (no dot in their rawValue) were left as flat `BOOLEAN` Remote Config parameters by the grouping change above. If one of these ever needed to grow into an object later, that would mean changing an *existing* parameter's `valueType` (bool → JSON) — which Firebase's `boolValue(forKey:)` reads as `false` for any legacy client (it only recognizes tokens like `"true"/"1"/"yes"`, not a JSON string), silently flipping the flag off for every user on an old build until they update. No crash, no forced-update trigger — just a silent regression.

**Decision:**
- `FeatureFlag.remoteConfigGroupKey` / `RemoteConfigKeyDefinition.remoteConfigGroupKey` (`FeatureFlags.swift`, `RemoteConfigCatalog.swift`) now return a catch-all group, `"misc"`, instead of `nil` for a bool flag with no dot namespace. Every bool flag is grouped now — only `min_app_version` (non-bool) stays a flat parameter. No other production code changed: `RemoteConfigCatalogDefaults`, `AppConfig`, `FlagOverridesViewModel` were already generic over "grouped vs flat" from the first grouping change.
- General policy going forward: **never change an existing Remote Config parameter's `valueType`.** Adding a new field to an existing group's JSON object is safe (old clients decoding `[String: Bool]` just ignore unknown keys) — that's the normal way to add a new flag. If a flag ever needs a genuinely different shape (e.g. an array), mint a *new* parameter key for it and let legacy clients keep reading the old key's compiled default; retire the old key later, gated by `min_app_version`, same as any other breaking migration.
- `FlagOverridesViewModel.isKnownRemoteConfigKey` already prunes a flag's stale pre-grouping flat key on init (added in the first grouping change) — this extends unchanged to `orders`/`suppliers`/`expenses`' own keys, which are no longer valid storage locations either.
- Firebase console (`apoorva-debug-8f9eb`): redeployed with 12 parameters — 10 named-namespace JSON groups + the new `misc` JSON group + `min_app_version` (string). Deploying the Remote Config template is a full replace, not a merge, so the old flat `orders`/`suppliers`/`expenses` `BOOLEAN` parameters were removed automatically; confirmed via `firebase remoteconfig:get`.

## Update 2026-11-28 (later still): standalone modules are each their own group, not `misc` or a combined `modules` group

**Request:** keep `orders`/`suppliers`/`expenses` out of the generic `misc` catch-all — each gets its own dedicated group (not one shared group), and each module's value is `{"enabled": true}` rather than a flat bool, so a module can grow a second property later (e.g. a delivery-only setting) without ever changing its field's shape either.

**Correction:** the first pass at this introduced a single combined `modules` group holding all three, plus a `FeatureToggle` value type and a `RemoteConfigGroupFieldValue` generalization to support it — that was a misreading of the request (asked for three *separate* groups, not one shared one) and unnecessary complexity on top of the misreading (`{"enabled": true}` is just a one-key `[String: Bool]` object, no new value type needed). Reverted both; see the actual decision below.

**Decision:**
- `orders`, `suppliers`, `expenses` are each their own one-member Remote Config group, named after themselves, with a single field `"enabled"` (e.g. parameter `orders` → `{"enabled": true}`) — structurally identical to the existing single-member groups (`printing` → `bluetooth`, `kill` → `sync_writes`, etc.), just with the field named `"enabled"` instead of the flag's own name. No new value type: everything stays `[String: Bool]`.
- `FeatureFlag`/`RemoteConfigKeyDefinition.remoteConfigGroupKey` special-case `orders`/`suppliers`/`expenses` → their own `rawValue` (checked before falling through to `"misc"`); `remoteConfigFieldName` special-cases the same three → `"enabled"`. `AppConfig.resolveBool`, `RemoteConfigCatalogDefaults.make()`, `FlagOverridesViewModel` are all unchanged from the first grouping round — no toggle-value branching needed.
- `misc` stays genuinely empty/reserved — nothing maps there today, so no Firebase parameter exists for it.
- **Bug caught and fixed while first extending this (still applies)**: `FlagOverridesViewModel.overrideDisplayValue`'s original (first-grouping-round) implementation marked a sibling field as "Overridden" merely because it was *present* in the stored group blob — but overriding one field always snapshots every sibling into that blob (Remote Config overrides a parameter atomically, there's no partial-object override), so every sibling was always present. Fixed by comparing the stored field value against its live remote/default baseline — "overridden" now means "differs from baseline", not "present in the blob". For `orders`/`suppliers`/`expenses` this is moot in practice (each is a one-member group, no siblings), but the fix is still correct and still in place for `billing`/`auth`/etc.
- Firebase console (`apoorva-debug-8f9eb`): redeployed, 14 parameters — `orders`, `suppliers`, `expenses` each `{"enabled": true}`, replacing the short-lived combined `modules` parameter; confirmed via `firebase remoteconfig:get`.
- **Not yet run**: `scripts/build.sh ApoorvaModels/ApoorvaServices/ApoorvaModules test` — no iOS Simulator in this worktree. All reasoning above is from manual tracing, not a test run; verify before relying on it further.

## Update 2026-11-13: local flag override layer removed

- The bool "developer override" layer (`DeveloperTools.flagOverrides`, `FlagResolver` `developerOverride`, `FlagSource.developer`) and the Feature flags screen's "Local overrides" section were removed. The screen only overrides existing catalogue keys, through the Remote Config section (app layer); `setRemoteConfigOverride` ignores unknown keys and invented keys persisted earlier are pruned on init.
- Trade-off: an override changes only the app layer, so an org/store/role "off" can still win; forcing a flag on past those layers is no longer possible.
- New flags are created only in `FeatureFlag` and the Firebase console against the same key.
- Setting an override equal to the current remote/default value clears it instead of storing it, so the "Overridden" badge disappears when a row is set back to its remote value.
