# POS layout: quick grid (production style) alongside the standard POS

**Date:** 2026-11-13
**Context:** The production app bills through a grid of quick items, a FIND half sheet and an "Add <item>" half sheet (MRP, quantity, Final ₹ / % Off / ₹ Discount). We wanted that flow as a second POS design, while keeping the existing per-vertical `POSView` designs untouched. A feature flag will choose between them later.

## Exploration
- `POSView` already varies by `BillingStyle` (searchList/tileGrid/catalog/services). `NewBillCoordinatorView` builds `POSConfig` from `AppSession` flags and owns every route and sheet.
- `CartItem.DiscountType` already had `.finalPrice`, `.percentage` and `.amount`. The discount is always stored as `discountPercent`.
- No sales-frequency ("best seller") helper existed for POS. `InsightsViewModel` ranks top items, but only for the Money screens.

## Decision
- `POSLayout { standard, quickGrid }` on `POSConfig` (default `.standard`). The coordinator passes `.quickGrid` for now; no `FeatureFlag` case yet, and the flag goes in at that one line in `NewBillCoordinatorView.config`.
- New `QuickGridPOSView`, `FindItemsSheet`, `QuickAddLineSheet` (`POS/QuickGridPOSView.swift`) and `QuickAddLineViewModel`. Both layouts share the same `POSViewModel`, `POSAction` handling, checkout, hold and held bills.
- The customer row stays the existing picker `NavRow` (not inline name/phone fields), shared through `POSCustomerRow`. `POSBillDatePicker` is shared too.
- Quick items: `isHotkey` items first, then best sellers (units sold in the last 30 days, excluding cancelled/deleted/return bills and `custom-`/`package:` lines, loaded through `salesLoader`), then the first 8 items.
- Tapping an item always opens the add sheet (as in production), except variant and loose items, which keep their existing variant/weight sheets.
- In quick-grid mode, tapping a cart line opens the half-sheet editor instead of pushing `LineEditView`.
- An empty discount field means no discount. The production app shows "NaN%" and treats an empty final price as 100% off; this version does neither.
- Quick grid has no calculator mode and no parlour "done by" picker yet. A new line still picks up `posViewModel.doneBy`.
