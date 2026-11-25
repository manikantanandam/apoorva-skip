# App analytics (Firebase / GA4): what we log and why

**Date:** 2026-11-25
**Context:** We want Google Analytics to cover the whole billing app. Before this change it logged only `sign_in_method`, `bill_saved` and `trial_started`, plus the user properties set in `AppSession`.

## Exploration
- `AnalyticsServicing` (`ApoorvaServices/Observability`) already wraps Firebase. The event catalogue lives in `AnalyticsServicing.swift`, as static `AnalyticsEvent` factories.
- View models take `analyticsService: AnalyticsServicing = NoOpAnalyticsService()` as their last init parameter, and `ModulesContainer` injects the real service. Every feature screen builds its view model through a `ModulesContainer` factory, so wiring a factory covers the whole app.
- Navigation is route-state coordinators (`docs/decisions/coordinator-pattern.md`). Each coordinator view renders its routes through `destination(for:)`, which gives one place per area to name screens.
- `AnalyticsParameterValue` is flat: string, int, double, bool. GA4's `items` array isn't supported, and keeping it flat avoids depending on how Skip's Android bridge converts nested bundles.

## Decision
- **Screen views:** `View.trackScreen(_:in:)` (`ApoorvaAppCore/Router/Views/ScreenTracking.swift`) logs `screen_view` on `onAppear`. The name is `<area>_<route case>`; associated values (ids, phone numbers) are dropped. The service is passed down through an environment value set in `MainView`. Automatic screen reporting is turned off on iOS (`FirebaseAutomaticScreenReportingEnabled`) and Android (`google_analytics_automatic_screen_reporting_enabled`), because SwiftUI and the single Android activity would only report wrapper names.
- **Ecommerce:** uses the GA4 recommended event names `add_to_cart`, `remove_from_cart`, `begin_checkout`, `purchase` and `refund`, so the built-in Monetisation reports fill in without custom setup. `purchase.transaction_id` is the sale id. A return bill logs `refund` against the original sale, and a cancelled bill logs a full `refund` with no value. `bill_saved` stays for continuity with existing dashboards.
- **Amounts:** exact `value` + `currency: "INR"`, as the user chose on 2026-11-25. This replaces the earlier "no per-customer amounts" rule in docs/06. Names, phone numbers and free-text notes are still never sent; a cancel logs only the preset reason.
- **Reliability:** `SyncEngine` logs one `sync_completed` per `syncAll` pass (duration, collection count, failed count), never one per collection. It also logs `sync_failed` with the collection key and the error *type* name; the error message can contain data, so it isn't sent.

## Deferred
`onboarding_step`, `first_bill_saved` (needs a persisted first-bill flag), `search_used`, the monetisation-limit events (`limit_80pct`, `limit_reached`, …) and `firestore_usage`.

## Next steps outside the code
In the Firebase / GA4 console: mark `purchase` as a key event, register the custom parameters (`source`, `payment_type`, `item_count`, `category`, `kind`, `reason`) as custom dimensions, and turn on the BigQuery export.
