//
//  DocumentIDBackfill.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
import ManiLogger

private let logger = AppLogger(category: .network)

public struct DocumentIDBackfillResult: Sendable, Equatable {
    public var written = 0

    public init(written: Int = 0) {
        self.written = written
    }
}

/// One-off fix for sales written before every sale doc stored its own id: production docs carry
/// `id` == doc id, but earlier builds of this app wrote sales without it (`SaleService.addSale`
/// built its payload by hand and omitted `id`). Every pre-fix sale doc is missing it, so there's
/// nothing to read and compare first — the caller supplies the known local sale ids (already
/// mirrored from Firestore via sync, at no read cost) and this merge-writes `id` to each one
/// unconditionally. Merge-writing an already-correct doc is a harmless no-op, so it's safe to run
/// more than once. Every other collection's writer already encodes `id` via `Codable`, so this is
/// sales-only; customers are also left out — they're keyed by phone and have no `id` field.
public struct DocumentIDBackfill: Sendable {
    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func run(orgId: String, saleIds: [String]) async throws -> DocumentIDBackfillResult {
        let path = String.orgPath(orgId, .sales)
        for saleId in saleIds {
            try store.setData(["id": saleId], path: "\(path)/\(saleId)", merge: true)
        }
        logger.info("Document id backfill for \(orgId): \(saleIds.count) sale docs written")
        return DocumentIDBackfillResult(written: saleIds.count)
    }
}
