# Android readiness

- Android CI (`android-apk.yml`) was the first real Android build; the app was never Android-ready (`SKIP_NO_ANDROID=1`). Each CI run exposes the next Apple-only layer.
- Fixed: `skip checkup` removed; `skip export --android --no-ios --release`; `skip-firebase` 0.21.0+ (Swift 6.4 `SkipFirebaseCore` link fix) which needs `firebase-ios-sdk` 12.19.2; `ApoorvaServices` imports `SkipFirebase*` (re-exports Firebase on Apple); `FirestoreCoding.swift` aliases `Firestore.Encoder/Decoder` on Android.
- Next blocker: `no such module 'SwiftUI'` in plain packages. `skip-fuse-ui` ships a `SwiftUI` shim target inside the `SkipFuseUI` product only when `TARGET_OS_ANDROID` is set, so SwiftUI-importing packages need `SkipFuseUI` as an Android-conditional dependency (no `skipstone` plugin needed). Unverified until CI.
- Affected: `ManiSwiftUIComponents`, `ManiLogger` (external repos, need releases), `ApoorvaModules`, `ApoorvaAppCore`.
- Apple-only imports to guard: `UIKit`/`CoreImage` (`ApoorvaColor`, `UPIQRView`), `VisionKit` (`POSExtraScreens`), `Combine` (`ReceiptView`, `AuthScreens`), `Security` (`PinStore`), `os` (`AppLogger`).
- Also check: `google-services` Gradle plugin and Firebase init on Android.
- Phases and verification: see the plan (SwiftUI shim, guards, runtime config, device smoke test, cleanup of the temporary PR trigger and diagnostics step).

## Android gates (iOS/Android differences)

Each `#if os(Android)` gate is a deliberate gap. Goal first is a building APK; revisit these after the first working one. Add a row whenever a new gate is introduced.

| Where | Gate | Android behaviour vs iOS | Possible proper fix |
|---|---|---|---|
| `ManiLogger` `UI/LogDetailView.swift` | `textSelection` | Log text can't be selected | Share sheet (already offered) or Skip text-selection support |
| `ManiLogger` `UI/LogDetailView.swift` | `AttributedString.backgroundColor` | Search match is bold only, no tint | Overlay/segmented `Text` runs |
| `ManiLogger` `UI/LogViewerView.swift` | `safeAreaInset` | Filter header scrolls with the list, not pinned | `VStack` layout with header above the list |
| `ManiLogger` `Core/AppLogger.swift` | `canImport(os)` | No `os.Logger` console output; registered `LogSinks` only | Android log sink (`android.util.Log` via Skip) |
| `ManiSwiftUIComponents` `Theme/AndroidCompat.swift` | `maniBorder` | Border stroked centred, not inset (about half a line-width) | Inset the shape by `lineWidth / 2` once SkipSwiftUI supports it |
| `ManiSwiftUIComponents` `Theme/AndroidCompat.swift` | `monospacedDigit` (Font, Text) | No-op; digits may not align in columns | Fixed-width font or SkipSwiftUI support |
| `ManiSwiftUIComponents` `Gallery/ManiComponentGallery.swift` | whole file excluded | Dev gallery absent | None needed (dev-only) |
| `ApoorvaServices` `Firestore/FirestoreCoding.swift` | `Firestore.Encoder/Decoder` alias + own `decode(_:from:)` | Same API; decode goes through JSON (Timestamp/Date as seconds) because native Swift can't see skip-firebase's reified `decode` | Revisit if skip-firebase exposes a bridged decode |
| `ApoorvaServices` `Firestore/FirestoreStoring.swift` | `setData` | skip-firebase's `setData` is async, so it runs in a `Task`; errors are logged, not thrown | Expose an async `setData` in `FirestoreStoring` |
| `ApoorvaServices` `Observability/FirebasePerformanceMonitoringService.swift` | `startTrace` | Uses `sharedInstance().trace(name:)` + `start()` | None (parity) |
| `ApoorvaServices` `AuthService/AuthService.swift` | `EmailAuthProviderID`, `AuthStateDidChangeListenerHandle` | Local constant `"password"` and typealias to `AuthStateListener` | None (parity) |
| `ApoorvaServices` `RemoteConfig/FirebaseRemoteConfigService.swift` | `setDefaults` | No-op: Android has no in-app Remote Config defaults, so values fall back to type defaults until fetched | Convert `[String: NSObject]` to `AnyDynamicObject` |

| `ApoorvaModules` `Inventory/InventoryView.swift`, `Onboarding/OpeningBalances.swift` | `fileImporter`, `UniformTypeIdentifiers` | CSV import can't pick a file | Android document picker |
| `ApoorvaModules` `Inventory/InventoryView.swift` | `ShareLink` + `SharePreview`, `editMode` | No template download; categories reorder with up/down buttons instead of drag | Android share intent |
| `ApoorvaModules` `Components/EverySecond.swift` | `.task` loop replaces `Timer.publish`/Combine | Same countdowns on both platforms | None (parity) |
| `ApoorvaModules` `Resources/ApoorvaColor.swift` | `canImport(UIKit)` | System background is plain white on Android (no dark mode) | Theme-based background |
| `ApoorvaModules` `Checkout/UPIQRView.swift` | `canImport(CoreImage)` | QR icon instead of a real UPI QR | Pure-Swift QR generator |
| `ApoorvaModules` `Components/ScreenKit.swift` | `safeAreaInset`, `FlowLayout` | Bottom bar stacked under scroll view; chips wrap in an adaptive grid (equal-width cells, min 96pt) | Custom wrapping layout |
| `ApoorvaModules` `Components/AndroidCompat.swift` | `Grid`/`GridRow`, `contentShape`, `monospacedDigit`, `appBorder` | Attendance columns aligned via fixed widths; `contentShape` approximated with a 0.001-opacity background; borders inset via half-line padding | Real grid; native `contentShape`/`strokeBorder` once supported |
| `ApoorvaModules` `Customers/CustomerScreens.swift`, `CustomersView.swift` | `ImageRenderer`, `ShareSheet`, `UIApplication.open` | Statement PDF/PNG export returns nothing; share sheets are empty; call button runs in a `Task` | Android share intents and PDF rendering |
| `ApoorvaModules` `POS/POSView.swift`, `Money/MoneyScreens.swift`, `Sell/SellScreens.swift` | `.graphical` date picker, `DatePicker(in:)` | Plain date picker; min/max enforced by clamping in `onChange` (Sell, Money) so the value snaps back like iOS | Android graphical picker once supported |
| `ApoorvaModules` `Components/IconView.swift`, `ApoorvaAppCore` `MainView.swift` | `#Preview` | None (dev only) | None |

Planned, not yet gated: `VisionKit` scanner (`POSExtraScreens`) and `Security` Keychain (`PinStore`). The local build succeeded without touching them, so they may already be guarded; check before shipping.

## Local build

`scripts/android-export.sh` runs the same export as CI (about 80s incremental, 19 min clean) and prints de-duplicated errors. Its first success produced a 478 MB `Apoorva-release.apk`; the size needs investigation (likely multiple ABIs and unstripped libraries). Local results only match CI when Skip and the SwiftPM packages resolve to CI's versions; clear `~/Library/Caches/org.swift.swiftpm` and `app/.build` if they drift.
