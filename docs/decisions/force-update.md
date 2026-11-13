# Force update & flag overrides

- Force update is decided only by the `min_app_version` flag (`FeatureFlag.minAppVersion`), read via `AppContainer.appConfig.minAppVersion` (override-aware in Debug). `PlatformConfig.minAppVersion` and `org.minVersion` no longer feed `SessionPhaseReducer`.
- `SessionPhaseReducer.phase` takes `minAppVersion: String` instead of `platform:`.
- `ForceUpdateView` (ApoorvaModules/ForceUpdate) shows required vs installed version; `GlobalRouteView` reads them from `AppCoordinator.phase`.
- Known gap: the phase is recomputed on session/platform emissions and after the launch fetch, but not after Developer "Fetch now" or a debug override change.
- `FlagOverridesViewModel` holds flag + Remote Config override logic; `RemoteConfigRowDisplay` moved with it. It is built per screen by `AppContainer.makeFlagOverridesViewModel()`, not owned by `DeveloperSettingsViewModel`.
- Developer hub rows no longer use destination-closure `NavigationLink`s: `DeveloperSettingsView` takes `onOpen*` callbacks and `MoreCoordinatorView` pushes `DeveloperRoute.environment/.flags/.logs` onto the coordinator path, each screen with its own container-made VM.
