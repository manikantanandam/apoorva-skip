# 09 — Roadmap, Risks & Gaps

## 1. Milestones

| Phase | Scope | Exit criteria |
|-------|-------|---------------|
| M0 — Foundation | Docs finalised, design tokens + component kit, Debug/Production Firebase projects, CI build job | Build green on both configs |
| M1 — R1 Core | Sign-in (Google/phone/email), onboarding + opening balances, billing (4 verticals + Easy mode), payments setup, bills, customers, cashflow, offline sync | Offline bill + sync verified with 2 devices |
| M2 — R2 Business | Inventory, suppliers & purchases, orders, expenses & profit, warranty, insights & reports, daily summary, devices | Reports match manual totals on test data |
| M3 — Hardening | Crashlytics, flags, perf traces, rules tests, backup | Crash-free ≥ 99.5% in debug |
| M3b — R3 Growth & control | Admin (roles incl. Accountant, theme, font, flags, audit), plans, attendance & salary, offers, catalog share, widget, demo, platform console | One pilot shop per vertical bills end to end |
| M4 — Pilot | 3–5 real shops per vertical | Zero data-loss incidents for 4 weeks |
| M5 — Release | Store submission, staged rollout | Production stable for 2 weeks |

## 2. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Sync conflicts between POS and Apoorva lose data | Medium | High | Append-only money/stock events; conflict queue |
| Skip/Android parity gaps (Bluetooth printing, Firebase on Android) | High | Medium | Spike Android printer early; keep platform code behind protocols |
| Firestore cost from listeners | Medium | Medium | Scope listeners by date/shop; paginate; monitor reads |
| Firebase SDK breaking changes | Low | Medium | Pin versions; upgrade monthly |
| Tax rule changes (tax-enabled shops only) | Medium | Medium | Keep tax rules in Remote Config / data, not code |
| Single developer bus factor | High | High | Docs, runbook, CI automation |
| Data loss from bad migration | Low | High | Migration tests from every prior version, backup before migrate |

## 3. Open questions (decide before M1)
1. ~~Separate POS app?~~ Decided: one app, with billing styles per vertical (see 01).
1a. Can one org own stores of different verticals? (Assumed yes.)
1b. ~~Pricing~~ Decided: 30-day full trial → Free (100 bills/month, core) or Pro ₹199/month (see 01).
2. Login model for shop staff: phone OTP or email?
3. ~~Tax~~ Decided: optional org config (off / same rate / per item), not asked at registration.
4. Printer: Bluetooth thermal only, or also network/USB?
5. ~~Languages~~ Decided: English, Telugu, Hindi, Tamil, Kannada.
6. Pricing/licensing: free, subscription, or per-device?

## 4. Things you may have missed
- **Support & feedback:** in-app help, bug report with logs (user-initiated), contact channel.
- **Onboarding:** shop setup wizard, sample data toggle.
- **Data export / portability:** user can download all their data (also needed for DPDP).
- **Legal pages:** privacy policy, terms, deletion URL.
- **App review notes:** demo account for store reviewers.
- **Offline conflicts UI:** how a user resolves a flagged conflicting bill.
- **Time-zone & day boundaries:** "day" for cashflow must use shop timezone, not device.
- **Currency rounding rules:** define round-off for cash payments.
- **Number/receipt sequence:** gap-free invoice numbers per device need a strategy (reserve blocks from server).
- **Hardware:** barcode scanner via camera only in v1; external scanners later.
- **Accessibility audit** before store release.
- **Localization of receipts** in 5 languages (tax labels only when tax is on).
- **Load test** of local DB with 10k bills and 5k customers.
- **Disaster recovery drill:** restore from backup once per quarter.

## 4a. Scope freeze
The v1 feature scope and 140 designs (Clean style) are frozen (see 01 "Small-shop essentials" and 04 §3a). New ideas go to the v2 backlog in 01.

## 5. Next steps
1. Answer open questions above.
2. Build the SwiftUI component kit and ThemeStore from 04 and `/designs`.
3. Create Debug/Production Firebase projects and split config files (07).
4. Start M1 with the data model in 03.
