# Android readiness

- Android CI (`android-apk.yml`) was the first real Android build; the app was never Android-ready (`SKIP_NO_ANDROID=1`). Each CI run exposes the next Apple-only layer.
- Fixed: `skip checkup` removed; `skip export --android --no-ios --release`; `skip-firebase` 0.21.0+ (Swift 6.4 `SkipFirebaseCore` link fix) which needs `firebase-ios-sdk` 12.19.2; `ApoorvaServices` imports `SkipFirebase*` (re-exports Firebase on Apple); `FirestoreCoding.swift` aliases `Firestore.Encoder/Decoder` on Android.
- Next blocker: `no such module 'SwiftUI'` in plain packages. `skip-fuse-ui` ships a `SwiftUI` shim target inside the `SkipFuseUI` product only when `TARGET_OS_ANDROID` is set, so SwiftUI-importing packages need `SkipFuseUI` as an Android-conditional dependency (no `skipstone` plugin needed). Unverified until CI.
- Affected: `ManiSwiftUIComponents`, `ManiLogger` (external repos, need releases), `ApoorvaModules`, `ApoorvaAppCore`.
- Apple-only imports to guard: `UIKit`/`CoreImage` (`ApoorvaColor`, `UPIQRView`), `VisionKit` (`POSExtraScreens`), `Combine` (`ReceiptView`, `AuthScreens`), `Security` (`PinStore`), `os` (`AppLogger`).
- Also check: `google-services` Gradle plugin and Firebase init on Android.
- Phases and verification: see the plan (SwiftUI shim, guards, runtime config, device smoke test, cleanup of the temporary PR trigger and diagnostics step).
