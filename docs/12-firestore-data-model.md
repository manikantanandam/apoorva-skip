# 12 — Firestore Data Model (as-is snapshot)

Baseline of the **live** Firestore structure as read by this app. Derived from code (`libraries/ApoorvaModels`, `libraries/ApoorvaServices`), not from the live database. Items marked **⚠ verify** must be confirmed against live data (read-only, Firebase console).

## 1. Overview

- Tenancy is by **path**: everything lives under `organizations/{orgId}`. No `orgId`/`shopId` field on documents.
- Auth: Firebase Auth email + password only (`AuthService.swift:32`).
- The selected org comes from `users/{uid}.selectedOrganization.orgId`; `assignedOrgs` limits what can sync.
- Inventory and orgs are **read-only** from this app. Writes: cashflow, daily summaries, `users/{uid}` (`selectedOrganization`, `updatedTimestamp`), plus — as of the POS selling flow — new `sales` docs (`SaleService.addSale`, never edits/deletes an existing sale) and scoped `customers` stat bumps after a sale (`CustomerService.upsertCustomerAfterSale`: creates the doc on first sale, otherwise increments `totalSales`/`totalAmountSpent` and sets `lastPurchaseDate`). A new `heldBills` collection (hold-bill/draft carts) is fully read-write from this app.
- Data was created by a legacy (Dart/Flutter) app. This app reads it in place.

## 2. Collections

| Path | Doc ID | Service |
|---|---|---|
| `users/{uid}` | Firebase Auth uid | `UserService` |
| `organizations/{orgId}` | org id | `OrganizationService` |
| `organizations/{orgId}/inventory/{itemId}` | `InventoryItem.id` | `InventoryItemService` |
| `organizations/{orgId}/customers/{phone}` | phone number (write path added by `CustomerService.upsertCustomerAfterSale`; **⚠ verify** against pre-existing legacy docs) | `CustomerService` |
| `organizations/{orgId}/sales/{saleId}` | doc ID (not stored as a field) | `SaleService` |
| `organizations/{orgId}/cashflow/{txId}` | UUID string | `CashflowTransactionService` |
| `organizations/{orgId}/dailyCashflowSummaries/{dd-MM-yyyy}` | date string | `DailyCashflowSummaryService` |
| `organizations/{orgId}/heldBills/{id}` | UUID string | `HeldBillService` (new, read-write) |
| `organizations/{orgId}/customerLedger/{id}` | UUID string | `OrgCollectionService<CustomerLedgerEntry>` (new; signed dues entries: sale, payment, opening, advance, reversal) |
| `organizations/{orgId}/stockMovements/{id}` | UUID string | `OrgCollectionService<StockMovement>` (new; signed stock deltas with a reason) |
| `organizations/{orgId}/auditEvents/{id}` | UUID string | `OrgCollectionService<AuditEvent>` (new; append-only by convention — not enforced until rules exist) |

| `organizations/{orgId}/settings/org` | fixed id `org` | `OrgSettings`: profile (shop name, vertical, bill prefix, setup progress), tax, receipt, payments, theme (accent, Clean/Bold, font, lock), flags (org/store/role), permission matrix, plan. **Missing on legacy orgs** — the app treats that as "already set up" with defaults |
| `organizations/{orgId}/stores/{id}` | UUID string (`default` for the implicit single store) | `Store`: name, vertical, address, prefix, accent |
| `organizations/{orgId}/members/{uid}` | Firebase uid | `Member`: org role (owner/manager/cashier/accountant), store access, active/invited. Overrides the role derived from legacy `users.role`, which is never rewritten |
| `platform/config` | fixed | `PlatformConfig`: app-level flags (incl. `auth.*`), `minAppVersion`, default visual style, trial/free/grace limits. Written only by superAdmin from the console |

Every doc in a new org collection carries `updatedAt`, `isDeleted` and a server-set `serverUpdatedAt`.

Accounts are **embedded** in the org document (no subcollection). `InternalTransfer` has no Firestore collection. Collection-name constants: `FirebaseCollectionName.swift:10-17`; `"dailyCashflowSummaries"` is a literal.

## 3. Documents

Type column: TS = Firestore Timestamp, num = number.

### users/{uid} (`AppUser`)
| Field | Type | Notes |
|---|---|---|
| id | string | falls back to random UUID if missing |
| name, email, url, status | string | lenient decode, defaults |
| role | string | `standard`, `admin`, `manager`, `super_admin` |
| assignedOrgs | [OrganizationSnapshot] | |
| selectedOrganization | OrganizationSnapshot? | |
| createdAt | TS or **string** | legacy strings like `31 March 2026 at 19:53:12 UTC+05:30` |
| updatedAt | TS | |
| updatedTimestamp | num (epoch s) | written by app |
| isDeleted | bool | |

`OrganizationSnapshot`: `orgId`, `name`, `accentColor` (default `#FF5733`).

### organizations/{orgId} (`Organization`)
`id` string · `name` string (required) · `status` string (`Active`) · `createdAt` TS (required) · `minVersion` (`1.0.0`) · `currentTheme` (`Default`) · `accentColor` (`#FF5733`) · `accounts` [Account] · `establishedAtInMs` num · `updatedAt` TS · `isDeleted` bool.

`Account` (embedded): `id` string, `name`, `type` (`cash`|`bank`|`upi`), `currentBalance` num, `updatedAt` TS, `isDeleted` bool.

### inventory (`InventoryItem`, aliased `Category`)
`id`, `name` (default `Unknown Category`), `currentStock` int, `billMachineNumber` int, `lastSoldDate` TS?, `isHotkey` bool, `updatedAt` TS?, `isDeleted` bool. Decoded with `try?`: a date stored as a string silently becomes nil.

### customers (`Customer`)
Keys: `name`, `phone`, `createdAt`, `lastPurchaseDate`, `totalSales` int, `totalAmountSpent` num, `updatedAt`, `isDeleted`. No `id` key. Dates decode from Timestamp into epoch-seconds in the model; Encodable is **not** symmetric.

### sales (`Sale`)
`staffId` (`Unknown`), `customerPhone`, `customerName` (`Walk-in`), `items` [SaleItem], `subtotal`, `overallDiscountPercent`, `overallDiscountAmount`, `roundOff`, `netPayable` (num), `payments` map PaymentMode→num, `timestamp` TS, `source` (`Unknown`), `status` (`Completed`), `whatsappStatus` (`unsent`), `updatedAt` TS?, `isDeleted`.

`SaleItem`: `cat_id` (→ categoryId), `categoryName`, `qty`, `stickerPrice`, `finalPrice`, `discountType` (`percentage`|`amount`|`finalPrice`).
`PaymentMode`: `cash`, `upi`, `card`, `credit`.

### cashflow (`CashflowTransaction`)
Required: `id`, `timestamp` TS, `particulars`, `amount` num, `transactionType` (`credit`|`debit`|`unknown`), `paymentMode` (`cash`|`upi`|`unknown`), `category`, `isDeleted`, `updatedAt` TS.
Optional/defaulted: `subCategory`, `fromAccountId`, `toAccountId` (`""`), `person`, `timestampInMs`, `updatedAtInMs` (num, default 0).

### dailyCashflowSummaries (`DailyCashflowSummary`)
`id` (`dd-MM-yyyy`), `date` TS, `openingBalances` [AccountBalance] (required), `closingBalances` (default `[]`), `updatedAt` **num** (not TS), `locked` bool. `AccountBalance`: `id`, `name`, `balance`.

## 4. Enum raw values

- **CashflowCategory** (stored as display string): `Shop Setup`, `Sales Revenue`, `Inventory`, `Internal Transfer`, `Maintenance & Repairs`, `Miscellaneous`, `Utilities`, `Unknown`. Unrecognised → `.unknown`.
- **CashflowSubCategory**: Painting, Woodwork, Sales Revenue, Ready Stock, Internal Transfer, Pooja/Festival, General, Phone/Recharge, Electricity, Rent, Transport, Food, Cleaning, Other Setup, Packaging, Stationary, Online, AC, CCTV, Glass Work, Mobile, Internet, Ceiling, Unknown. Missing → `.unknown`.
- **Hardcoded account IDs** (`CashflowTransaction.swift:31-42`): cash `b5ca46b1-8bb6-4c02-a42e-5d8507c04735`, upi `6b4b14b1-b8cb-4f7f-8881-91852e85b938`.

## 5. Conventions

- **Timestamps are mixed**: Firestore Timestamp (most), epoch-seconds numbers (`AppUser.updatedTimestamp`, `DailyCashflowSummary.updatedAt`, customers in model), legacy strings (`AppUser.createdAt`).
- **`*InMs` fields** (`timestampInMs`, `updatedAtInMs`, `establishedAtInMs`) are written with `timeIntervalSince1970` (seconds) at `CashflowTransactionService.swift:56`. **⚠ verify** unit in legacy data.
- **Soft delete**: `isDeleted: Bool`. Queries do not filter it; deleted docs sync down. Remote soft delete exists only for cashflow (sets `isDeleted` + `updatedAt`, not `updatedAtInMs`).
- **Writes**: cashflow/summary add skips if the doc exists; update uses `setData(merge: true)` and stamps `updatedAt`.

## 6. Delta-sync queries

| Collection | Filter |
|---|---|
| cashflow | `updatedAt > t` |
| sales | `timestamp > t OR updatedAt > t OR serverUpdatedAt > t` (cancels and edits bump `updatedAt`/`serverUpdatedAt`, so they reach other devices) |
| customers | `updatedAt > t OR lastPurchaseDate > t` |
| inventory | `updatedAt > t OR lastSoldDate > t` |
| new org collections (`customerLedger`, `stockMovements`, `auditEvents`, …) | `serverUpdatedAt > t` (server commit time, immune to client clock drift) |

Cursors store the newest date seen across every field the query matches, and each fetch re-reads a 10-minute overlap window (`SyncCursor`). Re-reads are harmless because local writes are upserts.
| organizations | `id in [assigned] AND updatedAt > t` (≤30 ids; queries field `id`, not doc ID) |
| dailyCashflowSummaries | `updatedAt > Timestamp(t)` — **⚠ verify**: model treats `updatedAt` as number, a Timestamp comparison won't match numeric values |

OR / `in`+range queries may need composite indexes managed outside the repo.

## 7. Local SQLite mapping (SkipSQL, active)

Schema is versioned by `SchemaMigrations` (`ApoorvaOfflineStorage/SkipSQL/Migrations/SchemaMigrations.swift`), run through SkipSQL's `migrate` and tracked in `PRAGMA user_version`. Steps are append-only; never edit a shipped step.
Tables: `ItemCategory` (inventory), `Customer` (PK `phone`), `Sale`, `CashflowTransaction`, `DailyCashflowSummary`, `Organization`, `HeldBill`, `SyncState` (local only; cursor per table/collection), and `OrgDocument` (PK `collection, id`; one JSON payload per document for every new org collection, so adding a collection needs no migration).
Encoding: dates REAL epoch seconds; bools INT 0/1 (inventory uses TEXT "true"/"false"); nested arrays/maps as JSON TEXT. Users cached in `UserDefaults` (`user_{id}`). Writes go through SkipSQL upserts, not hand-written column lists, so new columns aren't reset to NULL on sync.

**Additive fields (v2 migration, all optional on Firestore and locally):**

| Model | Fields |
|---|---|
| Sale | `cancelReason`, `cancelledAt`, `cancelledBy`, `editReason`, `editedAt`, `storeId`, `billNumber`, `returnOfSaleId`, plus `serverUpdatedAt` on new/edited docs |
| InventoryItem | `barcode`, `sellPrice`, `costPrice`, `wholesalePrice`, `categoryId`, `unit`, `lowStockThreshold`, `imageURLs`, `designCode`, `variantsJSON`, `warrantyMonths` |
| Customer | `creditLimit`, `birthday`, `dueBalance` (local cache of the ledger total), `priceTier`, `notes`, `whatsappReceipts` |

## 8. Known quirks (⚠ verify / fix separately)

- Customer Firestore doc ID is the phone number (`CustomerService.upsertCustomerAfterSale` writes to `organizations/{orgId}/customers/{phone}`) — ⚠ verify this matches how the legacy app keyed existing docs before relying on it for updates (only creates/increments, never renames a doc).
- Sale `payments`: Swift dictionary keyed by an enum encodes as a flat array on write, so never write sales without a custom encoder — `SaleService.addSale` builds the payload by hand (`["payments": [mode.rawValue: amount]]`) instead of going through the generic `Firestore.Encoder()` path.
- Daily summary cursor saves `Date.now` instead of max `updatedAt` (`DailyCashflowSummaryRepository.swift:85-88`).
- ~~Local bugs~~ (fixed by the storage rewrite): inventory update/delete used table `Category`; customer delete used `WHERE id`; inventory wrote `updatedAt` from `lastSoldDate`; sales wrote `whatsappStatus` from `overallDiscountAmount`; customers required non-null dates.
- ~~Sale ids~~ (fixed): legacy sale docs have no `id` field, so every sale decoded with `id = ""` and collapsed into one local row. `FirestoreStoring.fetch` now fills `id` from the doc ID, and the v2 migration forces a full sales re-sync.
- ~~Sale payments read~~ (fixed): payments are stored as a string-keyed map; the decoder now reads that shape instead of expecting an array.
- ~~Sync cursors~~ (fixed): sales, customers and inventory picked the *oldest* date as the cursor (inverted comparator), and sales stored `updatedAt` while querying `timestamp`.
- `Customer.id` is now the phone number (it was a fresh UUID on every decode, so it couldn't be used to look a customer up).
- `FirestoreSyncService` appears to be unused.
- Planned designs in docs 03/08/10 (`orgs/{orgId}/stores`, `shopId`, claims, paise) do **not** match the live structure.

## 9. Compatibility rules (additive-only)

The live app and production data must not be affected.

1. Never rename, remove, or retype an existing field or collection.
2. New fields must be optional with a safe default; old readers must ignore them.
3. Never change doc ID formats (`dd-MM-yyyy`, UUIDs, uid).
4. Match the existing encoding when writing legacy-owned fields (Timestamp vs number). Do not "normalize" them.
5. Put new features in new collections/field names, not overloaded existing ones.
6. Writes to legacy collections are signed off only in these additive shapes:
   - `sales`: new docs (`SaleService.addSale`); status change to `"Cancelled"` with `cancelReason`/`cancelledBy`/`cancelledAt` (`updateSaleStatus`, never deletes); edits of lines/totals/payments with `editReason`/`editedAt` (`updateSale`).
   - `customers`: post-sale stat bumps (`upsertCustomerAfterSale`) and, from the customers screens, creating/updating a customer with the additive fields above.
   - `inventory` and `organizations`: signed off for the inventory, shop setup and settings screens, additive optional fields only, `setData(merge: true)`; never retype or remove legacy fields.
   Anything broader needs its own sign-off. The legacy Dart app must tolerate `status: "Cancelled"` and unknown fields — ⚠ verify before shipping cancel.
7. Develop and test against the Firebase Emulator or a separate project, never production.
8. Don't deploy security rules or indexes without diffing against live config first.
9. Keep lenient decoders; never make a decoded field stricter.

## 10. Migration notes

- Version only new documents (e.g. `schemaVersion`); don't backfill legacy docs unless required.
- Any backfill: idempotent, batched, additive, run first against a copy/emulator, keep `updatedAt` semantics intact so delta sync picks changes up.
- Add a SkipSQL column-migration mechanism (e.g. a version table + `ALTER TABLE`) before any local schema change.

## 11. Repo gaps

- No `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc` tracked. Export from the console into the repo (read-only) to baseline them.
- `app/Darwin/GoogleService-Info.plist` is committed. Confirm its project ID matches the legacy app's, and decide whether it should stay tracked.
