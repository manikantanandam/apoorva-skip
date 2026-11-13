# 06 — Observability & Maintenance

## 1. Crash & error reporting — Firebase Crashlytics
- Integrated for iOS via `firebase-ios-sdk`; Android via Skip's Firebase bridge (verify before relying on it).
- **Implemented** behind `CrashReportingServicing` (`ApoorvaServices/Observability`), wired in `ServicesContainer`: non-fatal logging for sync failures (`SyncEngine`) and auth refresh failures (`AuthFlowViewModel.checkVerified`); `shopId` (hashed via `stableHash`), `appVersion`, `buildFlavor` custom keys set at launch/org-change; one breadcrumb call (`AppSession.configure`). DB migration errors, print failures and per-screen breadcrumbs are deferred follow-up.
- Custom keys per crash: `shopId` (hashed), `appVersion`, `buildFlavor`, `syncState`, relevant flag values.
- Breadcrumbs: screen name + last user action (no PII).
- dSYM upload on every release build (Crashlytics run-script or CI step).
- Alert: new crash issue spike > 2× baseline → email/Slack.

## 2. Analytics: two separate things

### 2a. Shop analytics (for the owner, in the app → Insights)
- Computed **on device from local SQLite**, so it works offline and needs no extra cloud reads.
- Views: sales trend (day/week/month/custom), bills, avg bill, margin, payment-mode split, top items/designs, slow movers, customers (repeat rate, new, dues ageing), staff leaderboard (sales, bills, discounts, service staff commission).
- Multi-store roll-up for org admins uses per-store daily summary docs (`stores/{id}/daily/{date}`), written at day close.
- Export to CSV/PDF behind the `insights.export` flag. Role-scoped: managers see their own store; staff see only their own stats.

### 2b. App analytics (for us, Firebase Analytics → BigQuery)
**Implemented** behind a provider-agnostic `AnalyticsServicing` abstraction (`ApoorvaServices/Observability`) — Firebase Analytics today, swappable for another vendor later without touching call sites. Wired: `sign_in_method` (`LoginViewModel`), `bill_saved` (`CheckoutViewModel`), `trial_started` (`ShopSetupViewModel`). `subscribed` is defined in `AnalyticsEvent` for schema completeness but left unwired — no real purchase/upgrade flow exists yet. The rest of the event table below is deferred follow-up.
No PII, no customer names, no per-customer amounts. Every event carries `vertical`, `role`, `app_version` and `plan` as user properties.

| Area | Events / metrics |
|------|------------------|
| Activation funnel | `onboarding_step` (1–4), `vertical_selected`, `first_bill_saved` (time from install) |
| Core usage | `bill_saved` (item count, mode, duration bucket), `bill_held`, `return_done`, `search_used`, `scan_used` |
| Feature adoption | `feature_opened` (name) by vertical and flag state; theme changes; admin actions |
| New features | `calculator_bill_saved`, `order_created`, `purchase_recorded`, `expense_added`, `warranty_claimed`, `sign_in_method` (google/phone/email), `font_changed`, `visual_style_changed`, `upi_verified`, `opening_balances_saved` |
| Monetisation funnel | `trial_started`, `trial_recap_viewed`, `limit_80pct`, `limit_reached`, `grace_bill_used`, `upgrade_viewed`, `subscribed` (plan, period), `downgraded_to_free` |
| Reliability | `sync_completed` (duration, count), `sync_failed` (reason), offline duration |
| Retention | D1/D7/D30 per vertical, weekly active shops, bills/shop/day |

Dashboards: activation per vertical, time-to-first-bill, feature adoption vs flag rollout, sync health, retention cohorts. A summary is in the in-app **Platform analytics** screen for the Apoorva team (see 10). The full analysis is in BigQuery.

## 3. Performance — Firebase Performance Monitoring
Custom traces: `save_bill`, `sync_push`, `sync_pull`, `dashboard_load`, `local_db_migration`.
Targets from 02 (NFR-02, NFR-05).
**Implemented**, behind `PerformanceMonitoringServicing` (`ApoorvaServices/Observability`): `save_bill` (`CheckoutViewModel.confirmSale`), `sync_push` (`SaleRepository.confirmSale`), `sync_pull` (`SyncEngine`, covers every registered repository). `dashboard_load` and `local_db_migration` are deferred follow-up.

## 4. Logging
**Implemented (Phase 1)** in the standalone `ManiLogger` library (github.com/manikantanandam/ManiLogger, pinned via `scripts/library-registry.json`), which also ships the Logs/Log detail screens. Call sites declare a file-scope `private let logger = AppLogger(category: .sync)`; every entry goes to `os.Logger` (Xcode console, subsystem = bundle id) and to the sinks `AppContainer` registers at launch:
- `LogBuffer` — last 500 entries, shown in Developer Settings → Logs (level filter, search, share, clear).
- `FileLogSink` — `Application Support/Logs/current.log` + `previous.log`, rotated at 1 MB. Shared from the Logs screen; source for Phase 2 upload.
- `CrashReportingLogSink` — warning+ entries forwarded to `CrashReportingServicing.log`, so they ride along on crash/non-fatal reports.
- Categories: `storage`, `sync`, `auth`, `network`, `ui`, `app`, `config`. Levels: debug, info, warning, error. Minimum level is debug in non-production environments, info in production.
- Each entry carries a per-launch `sessionId` for correlating logs with crash/analytics sessions.
- Release builds never log customer names, phone numbers, emails or amounts — log ids and counts only.

### Remote logs — planned
- **Phase 2 — on-demand upload (bug fixing):** Remote Config key `remote_log_upload_enabled` (targeted by RC conditions on hashed shopId / app version) plus a "Send logs to support" button. Gzip the rotated files and upload to Firebase Storage at `logs/{orgId}/{installId}/{timestamp}.log.gz`; Storage rules allow write-only to the caller's own path; a 14-day lifecycle rule deletes old files. Storage is chosen over Firestore (billed per document write) and Cloud Logging (needs a backend).
- **Phase 3a — user journey:** `screen_view` and key action events through `AnalyticsServicing` → BigQuery export for funnels. The `sessionId` in uploaded logs joins them to analytics sessions.
- **Phase 3b — cost:** count Firestore reads/writes/listener snapshots per feature in the Firestore services; emit one aggregated daily `firestore_usage` analytics event (never per-operation events) to find read hotspots. The `Fetched N <entity>` info logs already show per-sync document counts locally.

## 5. Sync health
- Outbox table: pending count, oldest pending age, last success timestamp.
- Settings → Sync status (S15) shows these to the user.
- Alert in Firestore-side monitoring when a shop has pending > 24 h (via scheduled Cloud Function, later).

## 6. Alerting & on-call (lightweight)
| Signal | Threshold | Action |
|--------|-----------|--------|
| Crash-free users | < 99.5% | Investigate; consider kill switch |
| Sync failure rate | > 2% over 1 h | Check Firestore quota / rules |
| Cloud costs | > budget 80% | Review reads (listeners) |
| Min version adoption | < 80% after 14 days | Nudge in-app |

## 7. Data maintenance
- **Backups:** daily Firestore managed export to a Cloud Storage bucket (30-day retention); on-device JSON export from Settings.
- **Migrations:** versioned SQLite migrations, tested with a fixture DB from each prior version; never destructive without backup.
- **Soft delete purge:** job removes `isDeleted` rows older than 90 days after confirmed sync.
- **Index review:** quarterly, check slow queries from Performance traces.
- **Dependency updates:** monthly Renovate/Dependabot PRs; Firebase SDK pinned to tested minor.

## 8. Runbook (short)
1. Spike in crashes → check release version, feature flags, last deploy.
2. Sync stuck for one shop → check `sync_failed` reasons, rules, auth token, then support tool to reset outbox (dry run first).
3. Data complaint ("bill missing") → search by bill ID in Firestore and local export; never edit records manually, add a correcting entry.
4. Bad release → halt staged rollout in Play/App Store Connect, flip kill switch, hotfix.
