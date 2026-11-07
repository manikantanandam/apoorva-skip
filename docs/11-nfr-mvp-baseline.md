# 11 — NFR MVP baseline

Minimum non-functional bar for the Store MVP (v1 / R1). Full NFR list and rationale: [02 — Requirements](02-requirements.md). Work is tracked in the **Store MVP** milestone with the `nfr` label.

**Priority:** Must = release blocker. Should = ship with a known gap logged in [09](09-roadmap-and-risks.md). Later = after pilot.

| NFR | Priority | MVP minimum bar | Verification | Issue |
|-----|----------|-----------------|--------------|-------|
| 01 Offline | Must | All core flows work with no network | Airplane-mode pass | #31 |
| 02 Sync latency | Must | p95 < 60 s online (02 target of 30 s from M4) | Two-device timing test | #31 |
| 03 Integrity | Must | No lost writes, no duplicate bills | Kill-mid-sync test; outbox unit tests | #31 |
| 04 Conflicts | Must | LWW per field; money/stock append-only; conflicts flagged | Two-device conflict test | #31 |
| 05 Performance | Must | Screen < 300 ms; bill save < 200 ms | Load test on mid-range device | #32 |
| 06 Security | Must | TLS; device encryption; SQLCipher optional | Security checklist ([08](08-security-and-compliance.md)) | #33, #34 |
| 07 Privacy | Must | Minimal PII; soft delete + purge; account deletion | Deletion walkthrough | #37 |
| 08 Accessibility | Should | Screen-reader labels, Dynamic Type, 4.5:1 contrast | Manual pass on core flows | #40 |
| 09 Localization | Should | English + one Indian language complete; others string-complete | Missing-string check | #40 |
| 10 Platform | Must | iOS 17+, Android 9+ | Smoke test on oldest OS | #41 |
| 11 Observability | Must | Crash-free ≥ 99% in pilot (99.5% from M3) | Crashlytics dashboard | #39 |
| 12 Maintainability | Must | Package graph boundaries kept | Review + build | #39 |
| 13 Testability | Must | ≥ 80% on Models, Repository, OfflineStorage | `scripts/build.sh all test --coverage`, Sonar | #39 |
| 14 Backup | Must | Daily backup + JSON export; restore ≤ 5 min; one drill pre-launch | Restore drill record | #38 |
| 15 App size | Should | < 30 MB | Release build size | #41 |
| 16 Theme switch | Later | < 100 ms | — | — |
| 17 Extensibility | Later | Design-only | — | — |
| 18 Ease of use | Should | New bill ≤ 2 taps | UX walkthrough | — |
| 19 Permissions | Must | Enforced server-side | Rules emulator tests | #33 |
| 20 Scale | Must | 10k bills / 5k customers / 5k items | Seeded load test | #32 |
| 21 Migration | Must | Upgrade test per released schema | Migration tests | #35 |
| 22 Atomic writes | Must | One transaction per sale/stock/cash operation | Kill-during-write test | #35 |
| 23 Money | Must | Exact totals; one rounding rule; shop time zone | Unit tests incl. edge cases | #36 |
| 24 Secrets | Must | gitleaks + Dependabot; keys outside repo | Seeded fake secret caught | #34 |
| 25 Rules tests | Must | Deny-by-default; emulator tests in CI | CI job | #33 |
| 26 Audit & retention | Should | Immutable events; purge window defined | Review | #37 |
| 27 Resilience | Should | Backoff retries; sync status visible | Flaky-network test | #31 |
| 28 Release quality | Must | CI + Sonar gate; crash-free blocks rollout | Branch protection | #39 |

## Release gate
Ship only when every Must row is verified and every Should row either passes or has a logged gap in [09](09-roadmap-and-risks.md).
