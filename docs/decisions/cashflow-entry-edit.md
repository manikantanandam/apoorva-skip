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

## Why
- Soft delete keeps delta sync and history intact and matches how other screens delete.
- Writing only the changed fields on delete, and rebuilding accounts only when needed, limits what we rewrite on legacy documents (docs/12 §9).
- Risk accepted: an edit rewrites the whole entry document via the existing `updateCashflowTransaction` (merge), so legacy docs get the model's encoding of every field. This is the same path the older edit screen already used.
- Not built or run: needs a manual check on a legacy entry and on a closed day.
