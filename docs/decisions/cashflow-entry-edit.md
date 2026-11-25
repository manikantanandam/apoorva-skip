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

## Badges or dropdown (2026-11-22)
- Category, sub-category and account can be chosen with badges (chips, the original layout) or with dropdown menus. A "Badges | Dropdown" menu sits in the navigation toolbar (top right) of both the add and edit cash entry screens; the choice is stored per device with `@AppStorage` (`cashEntry.selectionStyle`, default badges) and shared by the two screens. Dropdowns use one row per field (label, current value, chevron) that opens a `Menu`. Nothing about what is saved changes; this is presentation only.

## Internal transfer (2026-11-22)
- Cash entry now has three kinds: Cash in, Cash out and **Internal transfer** (a segmented control). A transfer asks for a **From account** and a **To account** (always different; picking the same one on both sides moves the other) and saves **one** entry with both `fromAccountId` and `toAccountId`, instead of the earlier two (a debit plus a credit). It needs at least two org accounts.
- The entry is `category`/`subCategory` Internal Transfer, `transactionType` **debit** (the Admin app only decodes credit and debit, so `unknown` would break it there) and `paymentMode` of the source account. `CashflowTransaction.isTransfer` = Internal Transfer category with both ids set.
- Day maths: `CashDay` now sums a drawer effect per entry (`cashEffect`): a transfer out of a cash account lowers cash, into one raises it, cash-to-cash and non-cash transfers change nothing; other entries still use payment mode and direction. Older single-sided transfer entries are judged by their one account id; entries with no ids fall back to mode and direction. Cash accounts come from the org (`type == .cash`) plus the fixed legacy cash id.
- The daily summary list already ignores Internal Transfer entries in income and expense, so a transfer doesn't distort profit.
- The day list shows a transfer with no +/- sign ("Internal Transfer · time"). Editing a transfer shows its two accounts (no direction or category); one-sided legacy transfers edit like ordinary entries.
- Not done: bill sales, expenses and the daily summary's opening and closing balances still key off the fixed cash id; a transfer doesn't update `organization.accounts[].currentBalance` (neither do other entries).

## Entry rows on the day screen (2026-11-22)
- The row title was the particulars, but the notes are optional (and the app writes a generated label into them, legacy entries say "No particulars"). Now: **title = sub-category** (else category, else the note, else "Entry"; "Internal Transfer" for transfers); **subtitle = category · account · time · note**, where the category is dropped if it equals the title and the note is only shown when there is one. The In/Out words are gone (the +/- sign already says it). A transfer's subtitle is "From → To · time · note".
- The account is the one money went to (cash in) or came from (cash out), by name from the org accounts (`CashDayViewModel.accounts`). Entries without an account id name the account matching their mode, or "Cash"/"Bank" if accounts aren't known.
- `noteText` strips what this app writes into particulars ("Rent", "Cash in", "Transfer A → B", optionally followed by " · note"), so only the real note shows; any other text (legacy descriptions) is shown as the note.

## PR #104 CodeRabbit fixes (2026-11-25)
- Account lookup failure: the org accounts loader now throws instead of returning `[]` (still `[]` when no org is selected). `CashDayViewModel` then shows an error + "Try again" and no totals; Close day is hidden and `DayCloseViewModel.canClose` is false, so a closing is never saved from a wrong expected amount. The entry/edit screens keep the old fallback (`try?`).
- Deleted cash accounts still count as cash when working out a day's transfers; they stay out of pickers and rows.
- Close day / add use the day screen's current `viewModel.date`, not the route date it was opened with.
- Shop setup is no longer offered on the entry/edit screens (the day screen hides those entries).
- `CashflowTransactionService.updateCashflowTransaction` leaves `category`/`subCategory` out of the merge write when they are `.unknown`, so a legacy value this app can't decode isn't overwritten with "Unknown". This replaces the "risk accepted" note below for categories.
- Transfers take an `id` (`MoneyRepositoryProtocol.addTransfer(id:)` → `CashBook.recordTransfer(id:)`); `CashEntryViewModel` keeps it after a failed save so a retry hits the same document (the service's add skips an existing id). Cash in/out entries don't do this yet.
- Not changed: edit lock still uses `isClosed` (a `DayClose`), not `closedDayKeys`. Legacy-closed days (summary with closing balances) have no reopen path in this app, so locking them would make them uneditable for good.

## Why
- Soft delete keeps delta sync and history intact and matches how other screens delete.
- Writing only the changed fields on delete, and rebuilding accounts only when needed, limits what we rewrite on legacy documents (docs/12 §9).
- Risk accepted: an edit rewrites the whole entry document via the existing `updateCashflowTransaction` (merge), so legacy docs get the model's encoding of every field. This is the same path the older edit screen already used.
- Not built or run: needs a manual check on a legacy entry and on a closed day.
