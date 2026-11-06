# 07 — Build, CI/CD

## 1. Build configurations

| Config | Purpose | Firebase project | Bundle ID (iOS) | Application ID (Android) | Logs | Flags |
|--------|---------|------------------|-----------------|--------------------------|------|-------|
| `Debug` | Local dev, simulator/emulator | `apoorva-dev` | `com.apoorva.app.dev` | `com.apoorva.app.dev` | verbose | overridable |
| `Staging` | QA, internal testers | `apoorva-stg` | `com.apoorva.app.stg` | `com.apoorva.app.stg` | info | remote |
| `Release` | App Store / Play | `apoorva-prod` | `com.apoorva.app` | `com.apoorva.app` | error | remote |

Notes:
- Bundle IDs above are proposals; confirm the real ones in `app/Darwin` and `app/Android` before use.
- One `GoogleService-Info.plist` / `google-services.json` per environment, kept out of git (CI injects from secrets).
- Use `.xcconfig` files per config for the iOS app; Skip's `Skip.env` for shared Skip settings.
- `SKIP_NO_ANDROID=1` is currently set — Android builds are off by default; flip per branch when testing Android.

## 2. Versioning
- `MARKETING_VERSION` semantic (1.2.0); `CURRENT_PROJECT_VERSION` = CI run number.
- Git tag per release: `v1.2.0`.
- Android `versionCode` derived from build number.

## 3. Local quality gates (already in repo)
- `scripts/build.sh <Module|all> [build|test] [--coverage]` — use this for libraries (repo rule).
- `scripts/install-tools.sh` — one-time xcbeautify install.
- Add pre-commit hook (optional): swift-format lint on staged Swift files.

## 4. CI (GitHub Actions) — extend `.github/workflows/ci.yml`

Current: detect testable modules → test each on macOS 15 with Xcode 26.3 → SonarCloud scan.

Proposed additions:

| Workflow | Trigger | Steps |
|----------|---------|-------|
| `ci.yml` (existing) | PR, push to main | Library tests + coverage + SonarCloud |
| `build-app.yml` | PR, push to main | `xcodebuild` iOS app build (Debug), `skip android build` only when Android enabled |
| `lint.yml` | PR | swift-format, markdown link check, secret scan (gitleaks) |
| `release-staging.yml` | push to `main` | Archive Staging, upload to TestFlight internal + Play internal track |
| `release-prod.yml` | tag `v*` | Archive Release, upload TestFlight / App Store review, Play production (staged 10%) |

Pipeline rules:
- Branch protection on `main`: required checks = tests, build, lint, SonarCloud quality gate.
- Secrets in GitHub Environments (`staging`, `production`): signing certs, provisioning profiles, Play service account JSON, Firebase plists, App Store Connect API key.
- Cache SwiftPM and Gradle to cut CI minutes.
- Concurrency group per branch to cancel superseded runs.

## 5. CD — signing & distribution
- iOS: fastlane `match` (or Xcode cloud) for certificates; App Store Connect API key, no password.
- Android: Play App Signing; upload key in CI secrets; internal → closed → production track.
- Release notes generated from PR titles (conventional commits recommended).

## 6. Release checklist
- [ ] All CI green, SonarCloud gate passed
- [ ] Migrations tested from previous version
- [ ] Remote Config defaults updated
- [ ] Crashlytics dSYM uploaded
- [ ] Staging smoke test (login, bill, sync, cashflow)
- [ ] Tag created, staged rollout started

## 7. Environments & data
- Dev and staging use separate Firestore databases; never point dev builds at prod.
- Seed script creates demo shop data for dev/staging only.

## 8. Gaps to decide
- Xcode Cloud vs GitHub Actions macOS runner (cost vs convenience).
- Whether Android CI runs on every PR (slower, needs emulator for `skip test`).
