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
| `ManiLogger` `UI/LogDetailView.swift` | `AttributedString.backgroundColor` | Search match is bold and accent-coloured, no background tint | Overlay/segmented `Text` runs |
| `ManiLogger` `UI/LogViewerView.swift` | `safeAreaInset` (removed) | Header sits above the list in a `VStack` on both platforms, pinned | None |
| `ManiLogger` `Core/AppLogger.swift` | `canImport(os)` | Android logs to logcat via `AndroidLogging` (`swift-android-native` 1.5.1+); no `privacy:` interpolation there | None |
| `ManiSwiftUIComponents` `Theme/AndroidCompat.swift` | `maniBorder` | Border stroked centred, not inset (about half a line-width) | Inset the shape by `lineWidth / 2` once SkipSwiftUI supports it |
| `ManiSwiftUIComponents` `Theme/AndroidCompat.swift` | `monospacedDigit` (Font, Text) | No-op; digits may not align in columns | Fixed-width font or SkipSwiftUI support |
| `ManiSwiftUIComponents` `Gallery/ManiComponentGallery.swift` | whole file excluded | Dev gallery absent | None needed (dev-only) |
| `ApoorvaServices` `Firestore/FirestoreCoding.swift` | `Firestore.Encoder/Decoder` alias + own `decode(_:from:)` | Same API; decode goes through JSON (Timestamp/Date as seconds) because native Swift can't see skip-firebase's reified `decode` | Revisit if skip-firebase exposes a bridged decode |
| `ApoorvaServices` `Firestore/FirestoreStoring.swift` | `setData` | skip-firebase's `setData` is async, so it runs in a `Task`; errors are logged, not thrown | Expose an async `setData` in `FirestoreStoring` |
| `ApoorvaServices` `Observability/FirebasePerformanceMonitoringService.swift` | `startTrace` | Uses `sharedInstance().trace(name:)` + `start()` | None (parity) |
| `ApoorvaServices` `AuthService/AuthService.swift` | `EmailAuthProviderID`, `AuthStateDidChangeListenerHandle` | Local constant `"password"` and typealias to `AuthStateListener` | None (parity) |
| `ApoorvaServices` `RemoteConfig/FirebaseRemoteConfigService.swift` | `setDefaults` | No-op: Android has no in-app Remote Config defaults, so values fall back to type defaults until fetched | Convert `[String: NSObject]` to `AnyDynamicObject` |

| `ApoorvaModules` `Inventory/InventoryView.swift`, `Onboarding/OpeningBalances.swift` | `fileImporter`, `UniformTypeIdentifiers` | CSV import uses `textFileImporter` (`Components/TextFilePicker.swift`): `fileImporter` on iOS; on Android the app injects `AndroidTextFilePicker` (`app/Sources/Apoorva/`), which starts the Kotlin `FilePicker` (`Android/.../FilePicker.kt`, launcher registered in `MainActivity`) via `AnyDynamicObject` and polls for the result. Unverified until CI/device | Replace polling if Skip gains Swift→Kotlin callbacks |
| `ApoorvaModules` `Inventory/InventoryView.swift` | `ShareLink` + `SharePreview`, `editMode` | No template download; categories reorder with up/down buttons instead of drag | Android share intent |
| `ApoorvaModules` `Components/EverySecond.swift` | `.task` loop replaces `Timer.publish`/Combine | Same countdowns on both platforms | None (parity) |
| `ApoorvaModules` `Resources/ApoorvaColor.swift` | `canImport(UIKit)` | System background is plain white on Android (no dark mode) | Theme-based background |
| `ApoorvaModules` `Checkout/UPIQRView.swift` | `canImport(CoreImage)` | Android draws the QR with the pure-Swift `QREncoder` (`QRCodeEncoder.swift`, byte mode, level M, v1–40, so long non-Latin payee names still fit); iOS keeps CoreImage. Unscanned so far: verify with a phone camera on the first APK | Use `QREncoder` on iOS too if the Android QR scans fine |
| `ApoorvaModules` `Components/ScreenKit.swift` | `safeAreaInset`, `FlowLayout` | Bottom bar stacked under scroll view; chips wrap in an adaptive grid (equal-width cells, min 96pt) | Custom wrapping layout |
| `ApoorvaModules` `Components/AndroidCompat.swift` | `Grid`/`GridRow`, `contentShape`, `monospacedDigit`, `appBorder` | Attendance columns aligned via fixed widths; `contentShape` approximated with a 0.001-opacity background; borders inset via half-line padding | Real grid; native `contentShape`/`strokeBorder` once supported |
| `ApoorvaModules` `Customers/CustomerScreens.swift`, `CustomersView.swift` | `ImageRenderer`, `ShareSheet`, `UIApplication.open` | Statement "Share on WhatsApp" builds a text payload (`StatementPDFSharer.swift`) that the app-injected `AndroidStatementPDF` hands to Kotlin `StatementPdf` (draws a PDF with `PdfDocument`, shares via `StatementFileProvider` + manifest provider); no PNG option on Android; customer list Export writes the CSV/vCard in Kotlin (`StatementPdf.shareText`) via the app-injected `AndroidTextFileSharer` and opens Android's share sheet; call uses `@Environment(\.openURL)` on both platforms; items template shares as text via `ShareLink` without a preview | PDF via a Kotlin bridge; file sharing/export via skip-kit `withDocumentExporter` (untested with Fuse) |
| `ApoorvaModules` `POS/POSView.swift`, `Money/MoneyScreens.swift`, `Sell/SellScreens.swift` | `.graphical` date picker, `DatePicker(in:)` | Plain date picker; min/max enforced by clamping in `onChange` (Sell, Money) so the value snaps back like iOS | Android graphical picker once supported |
| `ApoorvaModules` `Components/IconView.swift`, `ApoorvaAppCore` `MainView.swift` | `#Preview` | None (dev only) | None |

## Research: remaining Android features (skip-kit, SkipSwiftUI)

- SkipSwiftUI (`skip-fuse-ui`) `ShareLink(item: URL | String, subject:, message:) { label }` works on Android; only the `SharePreview` and `items:` variants are unavailable. The template download and text shares can use the no-preview form on both platforms.
- SkipSwiftUI has no `fileImporter`/`fileExporter` and no `ImageRenderer`.
- `skip-kit` (`https://source.skip.dev/skip-kit.git`, from 1.0.0) is a Skip Lite module: `withDocumentPicker`, `withDocumentExporter`, `withDocumentPreview`, `withMailComposer`, `openWebBrowser`. It has no share-sheet or PDF API, and its docs don't say whether it works from a Fuse (native) app; this is untested. Using it would also need a FileProvider and `file_paths.xml` in the Android project.
- skip-kit result: not usable from this Fuse app as is. Its `DocumentPicker.swift` is `#if !SKIP`-wrapped with a Kotlin (`#if SKIP`) Android branch and an iOS branch that calls `fileImporter`. Native Swift on Android has `SKIP` undefined, so it would compile the iOS branch against SkipSwiftUI, which has no `fileImporter`. The file has no `@bridge` annotations, so native code can't call the transpiled Kotlin either. Its `Package.swift` does have a `SKIP_BRIDGE` mode, but that only bridges types annotated for it.
- Remaining route for CSV import: a hand-written Kotlin file in `app/Sources/Apoorva/Skip/` that launches `ActivityResultContracts.OpenDocument`, copies the file to the cache and hands the text to Swift, bridged to the Swift side (`ApoorvaAppDelegate` already uses `/* SKIP @bridge */`). Unverified until CI.
- PDF/PNG statement rendering has no Skip-provided route; it needs Android `PdfDocument`/`Canvas` through a Kotlin bridge, or drawing the statement in pure Swift.

Planned, not yet gated: `VisionKit` scanner (`POSExtraScreens`) and `Security` Keychain (`PinStore`). The local build succeeded without touching them, so they may already be guarded; check before shipping.

## Local build

`scripts/android-export.sh` runs the same export as CI (about 80s incremental, 19 min clean) and prints de-duplicated errors. Its first success produced a 478 MB `Apoorva-release.apk`; the size needs investigation (likely multiple ABIs and unstripped libraries). Local results only match CI when Skip and the SwiftPM packages resolve to CI's versions; clear `~/Library/Caches/org.swift.swiftpm` and `app/.build` if they drift.
