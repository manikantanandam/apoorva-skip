# Cashflow entry edit and delete

**Date:** 2026-11-22
**Context:** The Cashflow day screen listed entries but they weren't tappable, so a wrong entry (including legacy "No particulars" ones) couldn't be fixed.

## Exploration
- `CashDayView` (`MoneyScreens.swift`) rendered `day.entries` as plain rows; only the "+" (add), "Close day" and "History" actions existed.
- Editing existed only on the older transaction list (`AddUpdateCashflowTransactionView`), unreachable from the day screen.
- `CashflowTransactionRepository.markAsDeleted` and `deleteCashflowTransaction` only touch the local cache, so they can't be used for a synced soft delete.
- `CashflowTransactionService.updateCashflowTransaction` writes the full model with `merge: true` and a new `updatedAt`; its `deleteCashflowTransaction(id:for:)` writes only `isDeleted` and `updatedAt` (it was missing from the service protocol).

## Decision
- Tapping an entry on an **open** day opens `CashEntryEditView`: direction (in/out), amount, particulars, mode (Cash/Bank). Date, category, person and id are kept. Account ids are rebuilt only if direction or mode changed, and a legacy `unknown` type or mode is left as it was unless the user changes it.
- Everything is editable, including entries created by the legacy app (owner's call), through `MoneyRepository.updateCashEntry`; each edit and delete writes an audit event (`cash.edit`, `cash.delete`).
- Delete is a **soft delete**: `CashflowTransactionRepositoryProtocol.softDeleteCashflowTransaction` writes only `isDeleted: true` and `updatedAt` to Firestore (so legacy docs keep every other field) and then syncs. A protocol default falls back to saving the entry with `isDeleted` set, so other conformers needn't implement it.
- Entries of a closed day stay read-only; the day must be reopened first. The automatic "Bill sales (cash)" row is not an entry and isn't editable.

## Date picker and calendar (2026-11-22)
- The date on the Cashflow day screen is tappable and opens a month calendar (`CashCalendarView`, a custom grid; the system `DatePicker` can't mark individual days). Tapping a past day jumps there (`CashDayViewModel.go(to:)`); future days are disabled and the next-month arrow stops at the current month. A "Today" button returns to today.
- Days are marked **green** when their closing balance is saved: a `DayClose` from this app that isn't deleted, or a legacy `dailyCashflowSummaries` doc with non-empty `closingBalances` (`CashDayViewModel.closedDayKeys`). Reopening a day removes its mark.
- Known mismatch: the day screen itself still treats only an app `DayClose` as "closed" (read-only, no Close button), so a legacy day marked green is still editable. Aligning them would change behaviour for legacy data, so it is left for a decision.

## Categories and sub-categories (2026-11-22)
- Source of truth is the Apoorva Admin app (`Apoorva Admin/Cashflow/AddCashflowView.swift`): 9 categories (incl. **Salary**) and a fixed category-to-sub-category mapping. Our enums were missing `Salary` and 11 sub-categories (Raw Materials, Water, Repairs, Pest Control, Wages, Advances, Bonuses, Walk-in, Wholesale, Custom Orders, Petrol); entries using them decoded as `.unknown`, so they showed no category here and an edit would have rewritten them as "Unknown". Added them (`CashflowCategory.salary`, `CashflowCategory.subCategories`, `CashflowCategory.selectable`).
- Day list rows now show "Category › Sub-category · In/Out · time · mode" (`CashflowTransaction.rowSubtitle`); unknown parts are skipped.
- Add cash entry replaced the five "purpose" badges with category chips plus that category's sub-category chips (default: Miscellaneous/General for out, Sales Revenue for in). `MoneyRepositoryProtocol.addCashEntry` now takes a `CashflowCategory` and `CashflowSubCategory?`. Particulars default to the sub-category name ("Cash in" for in), plus the note.
- Edit entry has the same pickers. Category and sub-category are written back only if the user changed them, so an unrecognised legacy value is preserved.
- Not offered for cash entries: Internal Transfer (needs two accounts) and Unknown. Not changed: `ExpenseCategory.cashflow` still maps Salary expenses to Miscellaneous/General and Rent to Utilities/Rent, which differs from Admin (Salary/Wages, Shop Setup or Maintenance/Rent); decide separately.

## Accounts: To / From (2026-11-22)
- Cash in now asks for the **To account** and cash out for the **From account**, chosen from the organization's embedded accounts (`organizations/{orgId}.accounts`, the same source the older transaction form uses). The Cash/Bank toggle on the edit screen is gone; the chosen account's type decides `paymentMode` (cash, else upi), so the day screen's cash maths is unchanged.
- The id goes on the matching side only (`toAccountId` for in, `fromAccountId` for out; the other stays empty), like `CashBook.record` already did. With no accounts loaded, add falls back to the fixed legacy cash account id.
- Why: `CashflowTransaction.PaymentMode.accountId` hardcodes the legacy ids (docs/12 §known issues) while `createShop` makes accounts with random ids, so entries on new orgs pointed at accounts that don't exist.
- Edit keeps an entry's account untouched unless the direction or account changed. Entries with no account id fall back to the account matching their mode for display only. An account id not in the org (old or legacy) is shown as "Original account" so it stays selectable.
- Still open (not changed here): `CashDay` and the daily summary use the fixed cash id for opening and closing balances, and bill sales and expenses still record with the fixed ids, so new orgs' balances may not line up with these entries.

## Why
- Soft delete keeps delta sync and history intact and matches how other screens delete.
- Writing only the changed fields on delete, and rebuilding accounts only when needed, limits what we rewrite on legacy documents (docs/12 §9).
- Risk accepted: an edit rewrites the whole entry document via the existing `updateCashflowTransaction` (merge), so legacy docs get the model's encoding of every field. This is the same path the older edit screen already used.
- Not built or run: needs a manual check on a legacy entry and on a closed day.
