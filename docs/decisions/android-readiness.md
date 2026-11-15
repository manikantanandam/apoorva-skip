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
| `ApoorvaServices` `Firestore/FirestoreCoding.swift` | `Firestore.Encoder/Decoder` alias | Same API, backed by `FirestoreEncoder/Decoder` | None (parity) |

Planned (phase 3, not yet gated): `UIKit`/`CoreImage` (`ApoorvaColor`, `UPIQRView`), `VisionKit` scanner (`POSExtraScreens`), `Combine` (`ReceiptView`, `AuthScreens`), `Security` Keychain (`PinStore`).
