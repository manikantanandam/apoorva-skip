# Firestore document IDs: match production (auto IDs, `id` field = doc ID)

**Date:** 2026-11-13
**Context:** In the console, sales written by this app had no `id` field, and new docs used UUID IDs. The production app (`Apoorva-Production`) uses Firestore auto IDs and stores each doc's ID in its `id` field. The new app must not drift from production's shape; otherwise the data would need a proper migration.

## Exploration
- A production sale (`organizations/lQONtvkfsgrWqyqcDF9Z/sales/0209aPrFedKKOIxk1npF`) has these fields: `customerName`, `customerPhone`, `id` (= doc ID), `items[]` (`cat_id`, `categoryName`, `discountType`, `finalPrice`, `qty`, `stickerPrice`), `netPayable`, `overallDiscountAmount`, `overallDiscountPercent`, `payments{cash}`, `roundOff`, `source`, `staffId`, `status`, `subtotal`, `timestamp`, `whatsappStatus`. It has no `billNumber`, `updatedAt`, `isDeleted` or `serverUpdatedAt`.
- The org's embedded `accounts[]` use UUID IDs in production.
- `SaleService.addSale` built its payload by hand and left out `id`. Everything else already matched: line keys, the `payments` map, `discountType` raw values.
- Model inits and creation sites defaulted to `UUID().uuidString`.
- Reads already inject the doc ID into `id` when it's missing (`FirestoreStoring` decode, `OrgCollectionService`), so in-app IDs always equalled doc IDs. Only the stored field was missing.
- Incremental sale sync ORs `timestamp`, `updatedAt` and `serverUpdatedAt`, so production docs without the newer fields still sync.

## Decision
- New `DocumentID.make()` (ApoorvaModels) generates 20 chars of `A-Za-z0-9`, Firestore's AutoId shape, offline. It replaces UUIDs for every Firestore document ID: model init defaults, sales, return sales, held bills, saved quick items, cashflow, and orgs.
- UUIDs stay where nothing becomes a document, or where production uses them:
  - cart `lineId` and `SaleItem.id`
  - `custom-` one-off items
  - SwiftUI-only ids, observer tokens, the PIN salt
  - `Account` ids (embedded in the org doc, UUIDs in production)
- `SaleService.addSale` and `updateSale` write `id`. The other writers already encode `id` through `Codable`.
- Migration:
  - Production data needs none.
  - Docs from earlier builds of this app get their `id` field from the debug-only Developer → "Backfill document IDs" (`DocumentIDBackfill`). It merge-writes only `id`, only where it's missing or wrong, and is idempotent.
  - Old UUID doc IDs stay as they are. Renaming them would mean rewriting every reference (`cat_id`, `saleId`, `returnOfSaleId`…) for no gain.
- Customers stay keyed by phone, and daily summaries by date. Bill-number collision handling isn't needed: doc IDs are random, and production has no `billNumber`.
