# UI testing

## Decisions
- **Target:** `ApoorvaUITests` (XCUITest bundle) in `app/Darwin/Apoorva.xcodeproj`, sources in `app/Darwin/UITests/`. Added as a Testable to the `Apoorva App` scheme.
- **Layout for growth:** one folder per feature (`UITests/Login/`), page objects in `UITests/Support/Screens/`, shared `AppLauncher` and `AccessibilityID`. Add new screens/modules the same way.
- **Stubbed auth:** launch arg `-UITesting` (DEBUG only, `UITestingConfig` in ApoorvaAppCore) swaps `ServicesContainer.authService` for `FakeAuthService` (ApoorvaServices), skips `FirebaseApp.configure` in `onInit()` and wipes UserDefaults. Credentials: `uitest@apoorva.app` / `UITest@123`.
- **Identifiers:** added at call sites in `AuthScreens.swift` (not in ManiSwiftUIComponents, to avoid a library release). Strings live in `ApoorvaModules/Onboarding/AccessibilityID.swift` and are mirrored in `UITests/Support/AccessibilityID.swift`; keep both in sync.
- **Runner:** `scripts/ui-test.sh [Class[/method]]` (separate from `build.sh`, which only handles `libraries/*`).

## CI
- `ui-tests` job in `.github/workflows/ci.yml` runs `scripts/ui-test.sh` on every PR and push to main (macos-15, iPhone 17). It is independent of the Sonar flow and uploads the log and xcresult on failure.
- It runs unconditionally (not module-filtered) because the app depends on every library. Add it as a required check in branch protection if wanted.

## Known risks
- Fixed: `FirebaseApp.configure()` never runs in `-UITesting` mode, so Firebase handles crashed (`FIRIllegalStateException`). Two fixes:
  - `FirebaseFirestoreStore` resolves Firestore lazily via `database()`, which throws when `FirebaseApp.app() == nil`; `listen` then emits one `nil` (missing doc) so the session still resolves (-> onboarding). Never capture an SDK handle at init.
  - `FakeRemoteConfigService` (serves catalog defaults only) replaces the Firebase one in `ServicesContainer` when `UITestingConfig.isEnabled`. Without the defaults, flags read false and the onboarding flow broke.
- Other Firebase-backed services (Analytics, Crashlytics, Remote Config, Firestore) are not stubbed; if one is touched before login in test mode it may crash because Firebase is not configured. Stub it in `ServicesContainer` when that happens.
- The debug build prefills the login form; `LoginScreen.replaceText` clears it before typing.
- Post-login assertion is "sign-in button disappears"; tighten it once a stable home-screen identifier exists.
