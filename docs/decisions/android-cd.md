# Android CD

- Every push to `main` builds an Android APK via `.github/workflows/android-apk.yml` (macOS 15, Skip CLI). iOS is excluded (no developer account).
- Delivery: GitHub pre-release `android-<sha7>`, newest 10 kept; also a workflow artifact.
- Signing: release build, debug-signed (no `keystore.properties`; `build.gradle.kts` falls back to debug). Switch to a keystore secret before Play distribution.
- `SKIP_NO_ANDROID=1` stays in committed `app/Skip.env`; CI strips it on the runner only. `CURRENT_PROJECT_VERSION` = run number.
- Secret required: `GOOGLE_SERVICE_JSON_B64` (base64 of Android `google-services.json`), written by `scripts/setup-firebase-config.sh`.
- No `skip checkup` in CI (removed 2026-11-15): it builds/tests Skip's own hello-skip sample and failed on its Kotlin test (`HelloSkipTests.classMethod`, ~7.5 min), unrelated to this app. Only `skip android sdk install` runs.
- Untested locally (no-build rule): first CI run may need tuning of Skip/SDK install steps or `skip export` flags.
