# UI testing

## Decisions
- **Target:** `ApoorvaUITests` (XCUITest bundle) in `app/Darwin/Apoorva.xcodeproj`, sources in `app/Darwin/UITests/`. Added as a Testable to the `Apoorva App` scheme.
- **Layout for growth:** one folder per feature (`UITests/Login/`), page objects in `UITests/Support/Screens/`, shared `AppLauncher` and `AccessibilityID`. Add new screens/modules the same way.
- **Stubbed auth:** launch arg `-UITesting` (DEBUG only, `UITestingConfig` in ApoorvaAppCore) swaps `ServicesContainer.authService` for `FakeAuthService` (ApoorvaServices), skips `FirebaseApp.configure` in `onInit()` and wipes UserDefaults. Credentials: `uitest@apoorva.app` / `UITest@123`.
- **Identifiers:** added at call sites in `AuthScreens.swift` (not in ManiSwiftUIComponents, to avoid a library release). Strings live in `ApoorvaModules/Onboarding/AccessibilityID.swift` and are mirrored in `UITests/Support/AccessibilityID.swift`; keep both in sync.
- **Runner:** `scripts/ui-test.sh [Class[/method]]` (separate from `build.sh`, which only handles `libraries/*`).

## CI
- `ui-tests` job in `.github/workflows/ci.yml` runs `scripts/ui-test.sh` on every push to main, and on PRs only when `app/`, `libraries/`, `.github/workflows/ci.yml` or the scripts the job runs (`ui-test.sh`, `setup-firebase-config.sh`, `build.sh`) change (`run_ui` output of `detect-modules`; Android workflows, other scripts, docs/designs/`.claude`/markdown-only PRs skip it). A new script the UI job calls must be added to that filter. macos-15, iPhone 17. Caveat: if `UI Tests` is a required check, a skipped job may block merges. It is independent of the Sonar flow and uploads the log and xcresult on failure.
- It runs unconditionally (not module-filtered) because the app depends on every library. Add it as a required check in branch protection if wanted.

## Feature tests (POS, customer picker)
- **Demo mode was removed (2026-11-20)** (`DemoSeeder`, `AppSession.isDemo`, `DemoShopView`, `setDemoUser`). The UI tests below that enter via the demo shop (`HomeScreen.enterDemoShop`, `POSUITests`, `CustomerPickerUITests`, `KiranaPOSUITests`) no longer have an entry point and need a new offline seeded entry (e.g. a `-UITesting` seed) before they can run.
- (Obsolete) Entry point is the demo shop: Splash "See a demo shop" -> "Try sample shop" (fancy vertical) -> "New bill" button. It seeds local SQLite only, so no Firestore/auth is needed. `HomeScreen` page object wraps this.
- New files must be registered by hand in `Apoorva.xcodeproj/project.pbxproj` (explicit file refs, no synchronized folders).
- The fancy POS is a quick-items grid (buttons labelled by item name), not a search list.
- Screens under a full-screen cover (New bill) leave Home in the accessibility tree, so static-text lookups like "Ravi Kumar" also match Home's recent bills. Use the picker's row button label (`", Name, "`) instead.
- Demo seeding is async and the local DB persists between launches, so the picker can open before customers exist. `CustomerPickerUITests.setUp` reopens the picker until the seeded customers show.
- Picker tests cover the focus rules: search focus hides the new-customer form and Recent; phone/name focus hides search, list, Recent and the bottom bar; submitting Name restores everything.
- Tapping a tile does not add to the cart: it opens the add-line half sheet (MRP, quantity, "Add to bill"), so the cart fills only after confirming. `POSScreen.addItem(named:)` does both steps.
- `POSUITests` now also covers add/edit/remove lines, quantity clamp, Find, quick item, bill discount (incl. manager PIN), hold/resume, checkout (credit blocked for walk-in, change due, split, hold), cash sale -> receipt -> new bill/home. POS identifiers (`AccessibilityID.Pos.*`, `QuickAddLine.*`) are set in `QuickGridPOSView`: toolbar buttons, More menu, Find, checkout, tiles (`pos.tile.<name>`), cart lines, MRP/discount fields, stepper, save/remove. Written without a simulator run: the discount-sheet "Percent" label, Split chip and cart-line tap target still need verifying with `scripts/ui-test.sh POSUITests/<method>`.
- Checkout tests (in `POSUITests`) cover card, UPI (pay screen, mark received, change mode, back), credit with/without customer, changing customer from checkout, discount/two-item totals, cash received/change, split (partial, full, cash+UPI, credit warning) and post-sale reset. Customer-creation tests (in `CustomerPickerUITests`) cover phone/name validation (9/10/11 digits, spaces, letters, blank/whitespace name), duplicate phone reuse, trimming, search edge cases and switching customers. All unrun: verify `splitSegment`, the keypad digit buttons and the phone prefill-from-search test first.
- `KiranaPOSUITests` runs against the kirana sample shop (`HomeScreen.enterDemoShop(sampleShop: "Sri Lakshmi Stores")`): weighed item "Onions (kg)" (weight sheet, presets, by-amount) and variant item "Tea Powder 250g". `DemoSeeder` now seeds sizes 100g/250g/500g on that one kirana item (`variantsJSON`) because no demo item had variants. Ids: `WeightSheet.*`, `VariantSheet.*`. Unrun; assumptions to check: sample-shop option is a button whose label contains the shop name, preset chip labels ("1 kg", "250 g"), and that the cart line shows "/kg" and the chosen size as static text.
- Bill discount mode segments are labelled "₹ amount" and "%" (not "Percent"). The demo has no manager PIN, so only the wrong-PIN path is testable ("That PIN isn't a manager's. Try again."). Close with items shows a confirmation dialog (Hold bill / Discard bill / Keep billing); `POSUITests` covers it plus undo-after-sale (skips if the role can't undo).
- Debugging: run one test (`scripts/ui-test.sh Class/method`), not the whole bundle.
- CI: the app target bundles both gitignored Firebase plists, so the `ui-tests` job runs `scripts/setup-firebase-config.sh` from repo secrets first. Without it the build fails ("Build input file cannot be found: GoogleService-Info-production.plist", PR #80).

## Known risks
- Fixed: `FirebaseApp.configure()` never runs in `-UITesting` mode, so Firebase handles crashed (`FIRIllegalStateException`). Two fixes:
  - `FirebaseFirestoreStore` resolves Firestore lazily via `database()`, which throws when `FirebaseApp.app() == nil`; `listen` then emits one `nil` (missing doc) so the session still resolves (-> onboarding). Never capture an SDK handle at init.
  - `FakeRemoteConfigService` (serves catalog defaults only) replaces the Firebase one in `ServicesContainer` when `UITestingConfig.isEnabled`. Without the defaults, flags read false and the onboarding flow broke.
- Other Firebase-backed services (Analytics, Crashlytics, Remote Config, Firestore) are not stubbed; if one is touched before login in test mode it may crash because Firebase is not configured. Stub it in `ServicesContainer` when that happens.
- The debug build prefills the login form; `LoginScreen.replaceText` clears it before typing.
- Post-login assertion is "sign-in button disappears"; tighten it once a stable home-screen identifier exists.
