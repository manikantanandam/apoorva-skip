# Android CD

- Every push to `main` builds an Android APK via `.github/workflows/android-apk.yml` (macOS 15, Skip CLI). iOS is excluded (no developer account).
- Delivery: GitHub pre-release `android-<sha7>`, newest 10 kept; also a workflow artifact.
- Signing: release build, debug-signed (no `keystore.properties`; `build.gradle.kts` falls back to debug). Switch to a keystore secret before Play distribution.
- `SKIP_NO_ANDROID=1` stays in committed `app/Skip.env`; CI strips it on the runner only. `CURRENT_PROJECT_VERSION` = run number.
- Secrets (2026-11-20): `GOOGLE_SERVICE_JSON_DEBUG_B64` (project `apoorva-debug-8f9eb`) and `GOOGLE_SERVICE_JSON_PRODUCTION_B64` (`apoorva-production`), both package `com.apoorva.app`. The google-services Gradle plugin reads one `google-services.json`, so `scripts/setup-firebase-config.sh` writes the one chosen by `GOOGLE_SERVICE_JSON_ENV` (CI sets `debug`; Android has no runtime env switch like iOS). The legacy `GOOGLE_SERVICE_JSON_B64` is still a fallback. The workflow fails if the debug secret is missing (2026-11-20): the run of `0f27a71` built without it and the APK crashed at launch ("crashed repeatedly") on a device.
- No `skip checkup` in CI (removed 2026-11-15): it builds/tests Skip's own hello-skip sample and failed on its Kotlin test (`HelloSkipTests.classMethod`, ~7.5 min), unrelated to this app. Only `skip android sdk install` runs.
- APK size (2026-11-16): the first APK was ~500 MB (arm64-v8a + armeabi-v7a + x86_64 native libs, ~150 MB each, `lib_FoundationICU.so` ~45 MB per ABI). CI now passes `--arch aarch64` to `skip export` (arm64 only, expect ~160 MB). Emulators (x86_64) and 32-bit devices are not supported by the CI APK.
- minSdk is 28 (Android 9+); a Lenovo TB-X304L on Android 8.1 cannot install it.
- Further size lever if needed: `keepDebugSymbols` in `app/Android/app/build.gradle.kts` keeps unstripped `.so` files.
- Untested locally (no-build rule): first CI run may need tuning of Skip/SDK install steps or `skip export` flags.
