//
//  DocumentIDBackfill.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
import ManiLogger

private let logger = AppLogger(category: .network)

public struct DocumentIDBackfillResult: Sendable, Equatable {
    public var scanned = 0
    public var updated = 0

    public init(scanned: Int = 0, updated: Int = 0) {
        self.scanned = scanned
        self.updated = updated
    }
}

/// One-off fix for docs written before every doc stored its own id: production docs carry
/// `id` == doc id, but earlier builds of this app wrote sales without it. Merge-writes only the
/// `id` field, only where it's missing or wrong, so it's safe to run more than once.
/// Customers are left out: they're keyed by phone and have no `id` field.
public struct DocumentIDBackfill: Sendable {
    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public static let collections: [String] = [
        .sales, .cashflow, .inventory, .heldBills, "dailyCashflowSummaries",
        ItemCategory.collection, Purchase.collection, SupplierLedgerEntry.collection, Expense.collection,
        DayClose.collection, AttendanceRecord.collection, SalaryPayment.collection,
        CustomerLedgerEntry.collection, StockMovement.collection, ServicePackage.collection,
        CustomerPackage.collection, Store.collection, Member.collection, Order.collection,
        WarrantyClaim.collection, AuditEvent.collection, Supplier.collection
    ]

    public func run(orgId: String, collections: [String] = Self.collections) async throws -> DocumentIDBackfillResult {
        var result = DocumentIDBackfillResult()
        for collection in collections {
            let path = String.orgPath(orgId, collection)
            let documents = try await store.getDocuments(collection: path, query: .all)
            for document in documents {
                result.scanned += 1
                guard document.data["id"] as? String != document.id else { continue }
                try store.setData(["id": document.id], path: "\(path)/\(document.id)", merge: true)
                result.updated += 1
            }
        }
        logger.info("Document id backfill for \(orgId): \(result.updated) of \(result.scanned) docs updated")
        return result
    }
}
