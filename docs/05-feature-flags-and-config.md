# 05 — Feature Flags & Remote Config

## Levels and resolution

```mermaid
flowchart LR
  K[App kill switch<br/>Remote Config] -->|off wins| R
  A[App level<br/>Remote Config<br/>Apoorva super admin] --> O[Organisation<br/>Firestore orgs/id/flags]
  O --> S[Store<br/>stores/id/flags]
  S --> RL[Role<br/>roles/id/flags]
  RL --> R((Resolved value))
```

Rules:
1. **App level decides availability.** If it is off, nobody gets the feature, whatever the org says. Admin UI shows it as "set by Apoorva" (locked).
2. **Org → Store → Role narrow it down.** A lower level can only turn a feature *off* or tune a value. It can never enable what a higher level disabled.
3. **Vertical defaults** seed org flags at onboarding (e.g. `billing.staff_commission` on for parlour).
4. **User preferences** (theme, compact lists) are not flags. They live in Settings.

## Implementation
- `FeatureFlagService` protocol in `ApoorvaServices`, with a `FlagResolver` that is a pure function in `ApoorvaModels`, fully unit tested.
- Sources: Firebase Remote Config (app level, compiled defaults) plus Firestore docs for org/store/role, cached in SQLite so flags work offline.
- View models ask `flags.isOn(.returns)`. Views never read Remote Config directly.
- Kill switches are checked at the start of each operation, not cached for the session.
- Developer settings (see 07) can override any flag locally and simulate plan state (trial day, bills used). Overrides live only on that phone, are never synced, and are available in debug builds or with the `developer` claim.

## Flag catalogue

| Key | Type | App default | Typical org/role use |
|-----|------|-------------|----------------------|
| `billing.credit_sales` | bool | on | Off for cashier role |
| `billing.returns` | bool | on | Managers only |
| `billing.discount_max_pct` | int | 100 | Cashier 10, manager 30 |
| `billing.hold_bills` | bool | on | — |
| `billing.split_payment` | bool | on | — |
| `printing.bluetooth` | bool | off | Per store with printer |
| `billing.staff_commission` | bool | on | Service shops: optional "done by" staff on lines |
| `inventory.edit` | bool | on | Off for cashier |
| `insights.view` | bool | on | Owner/manager |
| `insights.export` | bool | off | Rollout |
| `loyalty` | bool | off | Not released (app locked) |
| `multi_store` | bool | off | Pro plan |
| `plan.staff_accounts` / `plan.reports_export` / `plan.packages` | bool | off | Turned on by Pro plan or trial |
| `tax.enabled` | derived | off | From org `taxMode`, not a flag. Listed here so it is not duplicated as one |
| `sync.batch_size` / `sync.interval_sec` | int | 50 / 30 | App only |
| `kill.sync_writes` | bool | off | Emergency, app only |
| `auth.phone_otp` | bool | on | App only. Sign-in hub hides it when off |
| `auth.email_password` | bool | on | App only. Covers email sign-in and registration |
| `auth.google` | bool | on | App only |
| `auth.apple` | bool | off | App only. Must be on for iOS release if Google is on |
| `auth.email_verification_required` | bool | on | App only. Verify before cloud sync |
| `auth.registrations_open` | bool | on | App only. Off pauses new sign-ups; existing users unaffected |
| `billing.calculator_mode` | bool | on | Store setting picks the style; flag only hides it |
| `billing.wholesale_price` | bool | on | Org on/off |
| `billing.warranty` | bool | off | Org turns on (electronics/gifts); hidden otherwise |
| `orders` | bool | on | Jewellery/parlour default on, kirana on (delivery) |
| `suppliers` / `expenses` | bool | on | Off for cashier role |
| `staff.attendance` | bool | on | Plan Pro (needs staff accounts) |
| `offers.messages` | bool | on | Owner/manager only |
| `summary.whatsapp_auto` | bool | off | Owner opt-in |
| `plan.trial_days` / `plan.free_bill_limit` / `plan.grace_bills` | int | 30 / 100 / 10 | App only; tune via Remote Config |
| `min_app_version` | string | 1.0.0 | Force-update gate |

## UI config (not flags)
| Key | Levels | Default | Notes |
|-----|--------|---------|-------|
| `ui.visual_style` | App → org → store (user if not locked) | `clean` | `clean` or `bold`. App console sets the default for new orgs; org admin can switch and lock |
| `ui.font` | Org → store | `system` | One of `ui.fonts_allowed`; downloaded on demand, cached |
| `ui.fonts_allowed` | App only | 7 fonts | System, Inter, Poppins, Noto Sans, Hind, Mukta, Manrope |
| `payments.upi_id` / `payments.modes` | Org → store | — / cash, UPI, card, credit | Cheque off by default |
| `ui.accent` / `ui.theme_locked` | Org → store → user | Vertical default / off | See 04 theme resolution |

## Governance
- Each flag has an owner, created date and expiry. Remove release flags within 2 cycles after 100%.
- Admin changes to flags are written to the audit log (see 10).
- Flag values are attached as Crashlytics custom keys.

## Rollout
Internal shops → 10% of orgs (hash of orgId) → 100%. Roll back by flipping the app-level value, which takes effect on the next fetch or on foreground.
