# UI testing

## Decisions
- **Target:** `ApoorvaUITests` (XCUITest bundle) in `app/Darwin/Apoorva.xcodeproj`, sources in `app/Darwin/UITests/`. Added as a Testable to the `Apoorva App` scheme.
- **Layout for growth:** one folder per feature (`UITests/Login/`), page objects in `UITests/Support/Screens/`, shared `AppLauncher` and `AccessibilityID`. Add new screens/modules the same way.
- **Stubbed auth:** launch arg `-UITesting` (DEBUG only, `UITestingConfig` in ApoorvaAppCore) swaps `ServicesContainer.authService` for `FakeAuthService` (ApoorvaServices), skips `FirebaseApp.configure` in `onInit()` and wipes UserDefaults. Credentials: `uitest@apoorva.app` / `UITest@123`.
- **Identifiers:** added at call sites in `AuthScreens.swift` (not in ManiSwiftUIComponents, to avoid a library release). Strings live in `ApoorvaModules/Onboarding/AccessibilityID.swift` and are mirrored in `UITests/Support/AccessibilityID.swift`; keep both in sync.
- **Runner:** `scripts/ui-test.sh [Class[/method]]` (separate from `build.sh`, which only handles `libraries/*`).

## CI
- `ui-tests` job in `.github/workflows/ci.yml` runs `scripts/ui-test.sh` on every push to main, and on PRs only when `app/`, `libraries/`, `scripts/` or `.github/workflows/` change (`run_ui` output of `detect-modules`; docs/designs/`.claude`/markdown-only PRs skip it). macos-15, iPhone 17. Caveat: if `UI Tests` is a required check, a skipped job may block merges. It is independent of the Sonar flow and uploads the log and xcresult on failure.
- It runs unconditionally (not module-filtered) because the app depends on every library. Add it as a required check in branch protection if wanted.

## Feature tests (POS, customer picker)
- Entry point is the demo shop: Splash "See a demo shop" -> "Try sample shop" (fancy vertical) -> "New bill" button. It seeds local SQLite only, so no Firestore/auth is needed. `HomeScreen` page object wraps this.
- New files must be registered by hand in `Apoorva.xcodeproj/project.pbxproj` (explicit file refs, no synchronized folders).
- The fancy POS is a quick-items grid (buttons labelled by item name), not a search list.
- Screens under a full-screen cover (New bill) leave Home in the accessibility tree, so static-text lookups like "Ravi Kumar" also match Home's recent bills. Use the picker's row button label (`", Name, "`) instead.
- Demo seeding is async and the local DB persists between launches, so the picker can open before customers exist. `CustomerPickerUITests.setUp` reopens the picker until the seeded customers show.
- Picker tests cover the focus rules: search focus hides the new-customer form and Recent; phone/name focus hides search, list, Recent and the bottom bar; submitting Name restores everything.
- Not covered yet: tapping an item to fill the cart (cart stayed empty after the tap; needs a look at the tile's tap target).
- Debugging: run one test (`scripts/ui-test.sh Class/method`), not the whole bundle.
- CI: the app target bundles both gitignored Firebase plists, so the `ui-tests` job runs `scripts/setup-firebase-config.sh` from repo secrets first. Without it the build fails ("Build input file cannot be found: GoogleService-Info-production.plist", PR #80).

## Known risks
- Fixed: `FirebaseApp.configure()` never runs in `-UITesting` mode, so Firebase handles crashed (`FIRIllegalStateException`). Two fixes:
  - `FirebaseFirestoreStore` resolves Firestore lazily via `database()`, which throws when `FirebaseApp.app() == nil`; `listen` then emits one `nil` (missing doc) so the session still resolves (-> onboarding). Never capture an SDK handle at init.
  - `FakeRemoteConfigService` (serves catalog defaults only) replaces the Firebase one in `ServicesContainer` when `UITestingConfig.isEnabled`. Without the defaults, flags read false and the onboarding flow broke.
- Other Firebase-backed services (Analytics, Crashlytics, Remote Config, Firestore) are not stubbed; if one is touched before login in test mode it may crash because Firebase is not configured. Stub it in `ServicesContainer` when that happens.
- The debug build prefills the login form; `LoginScreen.replaceText` clears it before typing.
- Post-login assertion is "sign-in button disappears"; tighten it once a stable home-screen identifier exists.
