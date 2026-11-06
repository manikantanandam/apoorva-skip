# 06 — Observability & Maintenance

## 1. Crash & error reporting — Firebase Crashlytics
- Integrated for iOS via `firebase-ios-sdk`; Android via Skip's Firebase bridge (verify before relying on it).
- Enable **non-fatal logging** for: sync failures, DB migration errors, print failures, auth refresh failures.
- Custom keys per crash: `shopId` (hashed), `appVersion`, `buildFlavor`, `syncState`, relevant flag values.
- Breadcrumbs: screen name + last user action (no PII).
- dSYM upload on every release build (Crashlytics run-script or CI step).
- Alert: new crash issue spike > 2× baseline → email/Slack.

## 2. Analytics: two separate things

### 2a. Shop analytics (for the owner, in the app → Insights)
- Computed **on device from local SQLite**, so it works offline and needs no extra cloud reads.
- Views: sales trend (day/week/month/custom), bills, avg bill, margin, payment-mode split, top items/designs, slow movers, customers (repeat rate, new, dues ageing), staff leaderboard (sales, bills, discounts, stylist commission).
- Multi-store roll-up for org admins uses per-store daily summary docs (`stores/{id}/daily/{date}`), written at day close.
- Export to CSV/PDF behind the `insights.export` flag. Role-scoped: managers see their own store, stylists see only their own stats.

### 2b. App analytics (for us, Firebase Analytics → BigQuery)
No PII, no customer names, no per-customer amounts. Every event carries `vertical`, `role`, `app_version` and `plan` as user properties.

| Area | Events / metrics |
|------|------------------|
| Activation funnel | `onboarding_step` (1–4), `vertical_selected`, `first_bill_saved` (time from install) |
| Core usage | `bill_saved` (item count, mode, duration bucket), `bill_held`, `return_done`, `search_used`, `scan_used` |
| Feature adoption | `feature_opened` (name) by vertical and flag state; theme changes; admin actions |
| Reliability | `sync_completed` (duration, count), `sync_failed` (reason), offline duration |
| Retention | D1/D7/D30 per vertical, weekly active shops, bills/shop/day |

Dashboards: activation per vertical, time-to-first-bill, feature adoption vs flag rollout, sync health, retention cohorts.

## 3. Performance — Firebase Performance Monitoring
Custom traces: `save_bill`, `sync_push`, `sync_pull`, `dashboard_load`, `local_db_migration`.
Targets from 02 (NFR-02, NFR-05).

## 4. Logging
- Local `os.Logger` categories per module (`Storage`, `Sync`, `Auth`, `UI`).
- Levels: debug (dev only), info, error. Release builds never log customer names, phone numbers or amounts.
- Logs are not uploaded except error context via Crashlytics.

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
