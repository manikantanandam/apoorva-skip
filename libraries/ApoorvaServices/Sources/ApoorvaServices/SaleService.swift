//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels

public protocol SaleServiceProtocol: Sendable {

    func getSales(for orgId: String) async throws -> [Sale]
    func getSales(since lastSync: Date, for orgId: String) async throws -> [Sale]
    func addSale(_ sale: Sale, for orgId: String) async throws
}


public final class SaleService: SaleServiceProtocol {

    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func getSales(for orgId: String) async throws -> [Sale] {
        try await sales(for: orgId)
    }

    public func getSales(since lastSync: Date, for orgId: String) async throws -> [Sale] {
        try await sales(since: lastSync, for: orgId)
    }

    /// Writes a new sale doc. Builds the payload by hand instead of going through
    /// the generic `Firestore.Encoder()` path: `payments` is a `[PaymentMode: Double]`
    /// dictionary keyed by an enum, which the generic encoder mis-encodes as an array.
    public func addSale(_ sale: Sale, for orgId: String) async throws {
        let path = "\(String.orgPath(orgId, .sales))/\(sale.id)"

        var paymentsPayload: [String: Double] = [:]
        for (mode, amount) in sale.payments {
            paymentsPayload[mode.rawValue] = amount
        }

        let itemsPayload: [[String: Any]] = sale.items.map { item in
            [
                "cat_id": item.categoryId,
                "categoryName": item.categoryName,
                "qty": item.qty,
                "stickerPrice": item.stickerPrice,
                "finalPrice": item.finalPrice,
                "discountType": item.discountType.rawValue
            ]
        }

        let payload: [String: Any] = [
            "staffId": sale.staffId,
            "customerPhone": sale.customerPhone,
            "customerName": sale.customerName,
            "items": itemsPayload,
            "subtotal": sale.subtotal,
            "overallDiscountPercent": sale.overallDiscountPercent,
            "overallDiscountAmount": sale.overallDiscountAmount,
            "roundOff": sale.roundOff,
            "netPayable": sale.netPayable,
            "payments": paymentsPayload,
            "timestamp": sale.timestamp,
            "source": sale.source,
            "status": sale.status,
            "whatsappStatus": sale.whatsappStatus,
            "updatedAt": sale.updatedAt ?? sale.timestamp,
            "isDeleted": sale.isDeleted
        ]

        try store.setData(payload, path: path, merge: false)
    }
}

private extension SaleService {
    func sales(since lastSync: Date? = nil, for orgId: String) async throws -> [Sale] {
        var query = StoreQuery.all
        if let lastSync = lastSync {
            query = StoreQuery(conditions: [.greaterThan(field: "timestamp", date: lastSync)])
        }
        print("🌐 Fetching Sales for Org: \(orgId)...")
        let records = try await store.fetch(Sale.self, collection: .orgPath(orgId, .sales), query: query)
        print("✅ Fetched \(records.count) Sales.")
        return records
    }
}
