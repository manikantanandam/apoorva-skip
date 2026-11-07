# 02 — Requirements

## Functional requirements

| ID | Requirement | Implementation |
|----|-------------|----------------|
| FR-01 | Users log in and see only their shop's data | Firebase Auth + `shopId` claim; Firestore rules (see 08) |
| FR-02 | CRUD customers with phone lookup and dues | `ApoorvaModels` customer model; SQLite table with phone index; `CustomerRepository` |
| FR-03 | CRUD inventory items with stock in/out | `InventoryItemLocalStorageProtocol`; stock movements as append-only rows |
| FR-04 | List, filter, cancel bills and sales | `SaleRepository` reads local DB; cancel writes a status + reason, never deletes |
| FR-05 | Record cash in/out and daily summary | `Cashflow` module; `DailyCashflowSummary` view model computed from local rows |
| FR-06 | Show dashboard totals for today | Aggregate queries on local DB |
| FR-07 | Export reports to CSV/PDF | Generated on device from local data |
| FR-08 | Works fully offline; syncs later | Write local first, queue to outbox, `FirestoreSyncService` pushes/pulls |
| FR-09 | Shop profile (name, phone, address, bill prefix). No tax questions at registration | Settings module; stored per shop in Firestore + cached locally |
| FR-10 | Feature flags at app, org, store and role level | `FlagResolver` over Remote Config + Firestore overrides (see 05) |
| FR-11 | Shop chooses a vertical; billing UI and catalog fields follow it | `VerticalProfile` + `BillingStrategy` protocol (see 03) |
| FR-12 | User changes theme (accent, light/dark); admin can set and lock org/store theme | `ThemeStore` resolution order (see 04) |
| FR-13 | In-app admin: stores, staff, roles, permissions, theme, flags, audit | Admin module, owner-only (see 10) |
| FR-14 | Shop analytics: sales trend, items, customers/dues, staff | Local aggregate queries; no network needed (see 06) |
| FR-15 | Spot service billing (walk-ins) with optional "done by" staff for commission; no appointments or bookings | Parlour `BillingStrategy`; bill line `staffId` (optional) |
| FR-16 | Universal search across customers, bills, items and actions | SQLite FTS5 index |
| FR-17 | Optional tax: org config `taxMode` = off (default) / fixed / perItem, plus `pricesIncludeTax`, optional GSTIN | `TaxPolicy` in `ApoorvaModels`; item `taxRate` used only in perItem mode |
| FR-18 | 30-day full trial → Free (100 bills/month, core) or Pro; usage meter from 80%; soft stop with 10 grace bills; monthly reset; data always viewable/exportable | `PlanService`: local counter + server-verified count (Cloud Function); App Store / Play subscriptions |
| FR-19 | Org owner adds, invites, deactivates members | Admin module + Cloud Function for claims |
| FR-20 | Platform console: suspend/block/delete orgs, platform analytics, app flags | Hidden section for `superAdmin` claim; org `status` enforced by rules |
| FR-21 | UPI QR payment, quick item, weight entry, WhatsApp receipts and reminders | Billing module; share via system share sheet / WhatsApp intent |
| FR-22 | Sign in with Google, phone OTP or email/password; register with email; verify email; reset password; link methods. Each method on/off at app level | Firebase Auth providers; sign-in hub reads `auth.*` flags; see 05 and 08 |
| FR-23 | Easy mode: calculator billing with optional category per amount | `BillingStrategy` "calculator"; per-store setting |
| FR-24 | Quick staff switch with PIN / biometrics; app lock | Local PIN hash per member; LocalAuthentication / BiometricPrompt |
| FR-25 | Undo bill within 5 min; edit saved bill with reason | Undo = cancel with reason "undo"; edit = new version, old kept for audit |
| FR-26 | Retail/wholesale price tiers; units & packs | Item `prices[tier]`, `unit`, `packSize`; customer `defaultTier` |
| FR-27 | Optional warranty per item (value + days/months/years), shown on bill and receipt; lookup and claims | Item `warrantyValue`, `warrantyUnit`; line `warrantyUntil` stored at sale; `WarrantyClaim` |
| FR-28 | Orders with advance, due date, pickup/delivery; deliver → bill balance | `Order` entity linked to bill and payments |
| FR-29 | Suppliers, purchases (items or total, photo), supplier dues and payments, reorder list | `Supplier`, `Purchase` → stock movements + cash entries |
| FR-30 | Expenses with categories and monthly repeat; profit report | `Expense`; profit = sales − COGS − expenses |
| FR-31 | Daily summary at day close, optional auto WhatsApp to owner | Generated locally; WhatsApp share intent / push notification |
| FR-32 | Staff attendance, salary, advances, commission | `Attendance`, `SalaryEntry`; paid salary creates an expense |
| FR-33 | Contacts import, birthday wishes, offer messages, catalog share, demo shop, tips, widget | Contacts permission on demand; WidgetKit / Glance via Skip |
| FR-34 | Payments setup: UPI ID with ₹1 verification, payment modes on/off incl. cheque, UPI QR standee | Org config `payments.*`; QR generated on device |
| FR-35 | Opening balances for customers, suppliers and cash at onboarding | Opening ledger entries dated before the first bill |
| FR-36 | Devices list with remote sign-out | Firebase token revocation + device registry per member |
| FR-37 | Accountant read-only role | Built-in role; rules deny writes |
| FR-38 | Purchase return to supplier; read-only audited support sessions | Negative purchase reduces stock and dues; support session token with 30-min TTL and audit events |
| FR-39 | Developer settings: switch Debug / Production backends, flag overrides, plan simulator, logs, crash test, sync tools | Debug builds always; release only with `developer` claim (see 07) |

## Non-functional requirements

| ID | Category | Target | How |
|----|----------|--------|-----|
| NFR-01 | Availability | App usable 100% offline | Local SQLite as source of truth |
| NFR-02 | Sync latency | p95 < 30 s when online | Outbox + Firestore listeners; retries with backoff |
| NFR-03 | Data integrity | No lost writes, no duplicate bills | Client-generated UUIDs; idempotent upserts; outbox ack |
| NFR-04 | Conflict handling | Deterministic merge | Last-write-wins per field with `updatedAt` + `deviceId`; money/stock use append-only events |
| NFR-05 | Performance | Screen open < 300 ms on 3-yr-old mid-range phone; bill save < 200 ms | Indexed SQLite queries; paginated lists; no network on UI path |
| NFR-06 | Security | Data encrypted at rest and in transit | Firestore TLS; device-level encryption; SQLCipher option (see 08) |
| NFR-07 | Privacy | Minimal PII, deletion on request | Customer delete = soft delete + scheduled purge |
| NFR-08 | Accessibility | Dynamic Type, VoiceOver/TalkBack labels, 4.5:1 contrast | Design tokens in 04 meet contrast |
| NFR-09 | Localization | English, Telugu, Hindi, Tamil, Kannada (app and receipts set separately); currency ₹ with locale formatting | String catalogs / Android resources; date/number formatting independent of machine locale (per repo rule) |
| NFR-10 | Platform | iOS 17+, Android 9+ (API 28+) | Deployment targets set in Skip/Xcode |
| NFR-11 | Observability | Crash-free users ≥ 99.5% | Crashlytics + custom logs (see 06) |
| NFR-12 | Maintainability | Module boundaries enforced by package graph | SwiftPM libraries; no singletons; DI via `AppContainer` |
| NFR-13 | Testability | ≥ 80% coverage on libraries | `scripts/build.sh`, SonarCloud gate |
| NFR-14 | Backup | Daily automatic backup, restore in ≤ 5 min | Firestore export + on-device JSON export |
| NFR-15 | App size | < 30 MB install | Asset pruning, no large bundled fonts |
| NFR-16 | Theme switch | < 100 ms, no restart | Tokens in SwiftUI environment |
| NFR-17 | Extensibility | New vertical without touching billing core | Vertical profile is data + one strategy type |
| NFR-18 | Ease of use | New bill ≤ 2 taps from any tab; any feature ≤ 1 tap from a tab | Centre tab + More menu + universal search |
| NFR-19 | Permission correctness | Role limits enforced even if the UI is bypassed | Firestore rules are authoritative |

## Sync model (summary)
1. Every write goes to SQLite with `syncState = pending`.
2. Outbox worker pushes pending rows in batches; on success marks `synced`.
3. Firestore snapshot listeners pull remote changes into SQLite.
4. Conflicts resolved per NFR-04; conflicting bills are flagged for review, never silently dropped.

## Out of scope (v1)
Payment gateway integration, e-invoicing IRN, multi-currency, hardware POS terminals.
