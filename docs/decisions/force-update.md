# Force update & flag overrides

- Force update is decided only by the `min_app_version` flag (`FeatureFlag.minAppVersion`), read via `AppContainer.appConfig.minAppVersion` (override-aware in Debug). `PlatformConfig.minAppVersion` and `org.minVersion` no longer feed `SessionPhaseReducer`.
- `SessionPhaseReducer.phase` takes `minAppVersion: String` instead of `platform:`.
- `ForceUpdateView` (ApoorvaModules/ForceUpdate) shows required vs installed version; `GlobalRouteView` reads them from `AppCoordinator.phase`.
- The phase is recomputed on session/platform emissions, after the launch fetch, and whenever `FlagOverridesViewModel` reports a change (override set/reset, Fetch now) via `AppContainer.onConfigChanged`, so the cover dismisses without relaunch.
- In debug builds the force-update screen has a "Developer settings" button that opens `DeveloperCoordinatorView` (own `DeveloperCoordinator` path) in a sheet owned by `GlobalRouteView`; a sheet on `MainView` could not layer above its own full-screen cover.
- `FlagOverridesViewModel` holds flag + Remote Config override logic; `RemoteConfigRowDisplay` moved with it. It is built per screen by `AppContainer.makeFlagOverridesViewModel()`, not owned by `DeveloperSettingsViewModel`.
- Developer hub rows no longer use destination-closure `NavigationLink`s: `DeveloperSettingsView` takes `onOpen*` callbacks and `MoreCoordinatorView` pushes `DeveloperRoute.environment/.flags/.logs` onto the coordinator path, each screen with its own container-made VM.
