//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels
import ManiLogger

private let logger = AppLogger(category: .network)

public protocol SaleServiceProtocol: Sendable {

    func getSales(for orgId: String) async throws -> [Sale]
    func getSales(since lastSync: Date, for orgId: String) async throws -> [Sale]
    func addSale(_ sale: Sale, for orgId: String) async throws
    /// Soft status change on an existing sale (e.g. "Cancelled" with a reason). Never deletes.
    func updateSaleStatus(saleId: String, status: String, reason: String, by staffId: String, at date: Date, for orgId: String) async throws
    /// Rewrites an existing sale's lines and totals after an edit, recording why.
    func updateSale(_ sale: Sale, for orgId: String) async throws
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
        var payload = Self.linesPayload(for: sale)
        payload["id"] = sale.id
        payload["staffId"] = sale.staffId
        payload["customerPhone"] = sale.customerPhone
        payload["customerName"] = sale.customerName
        payload["timestamp"] = sale.timestamp
        payload["source"] = sale.source
        payload["status"] = sale.status
        payload["whatsappStatus"] = sale.whatsappStatus
        payload["updatedAt"] = sale.updatedAt ?? sale.timestamp
        payload["serverUpdatedAt"] = StoreSentinel.serverTimestamp
        payload["isDeleted"] = sale.isDeleted
        if let storeId = sale.storeId { payload["storeId"] = storeId }
        if let billNumber = sale.billNumber { payload["billNumber"] = billNumber }
        if let returnOfSaleId = sale.returnOfSaleId { payload["returnOfSaleId"] = returnOfSaleId }

        try store.setData(payload, path: Self.path(sale.id, orgId: orgId), merge: false)
    }

    public func updateSaleStatus(saleId: String, status: String, reason: String, by staffId: String, at date: Date, for orgId: String) async throws {
        try await store.updateData([
            "status": status,
            "cancelReason": reason,
            "cancelledBy": staffId,
            "cancelledAt": date,
            "updatedAt": date,
            "serverUpdatedAt": StoreSentinel.serverTimestamp
        ], path: Self.path(saleId, orgId: orgId))
    }

    public func updateSale(_ sale: Sale, for orgId: String) async throws {
        var fields = Self.linesPayload(for: sale)
        fields["customerPhone"] = sale.customerPhone
        fields["customerName"] = sale.customerName
        fields["editReason"] = sale.editReason ?? ""
        fields["editedAt"] = sale.editedAt ?? Date()
        fields["updatedAt"] = sale.editedAt ?? Date()
        fields["serverUpdatedAt"] = StoreSentinel.serverTimestamp
        try await store.updateData(fields, path: Self.path(sale.id, orgId: orgId))
    }

    static func path(_ saleId: String, orgId: String) -> String {
        "\(String.orgPath(orgId, .sales))/\(saleId)"
    }

    /// Lines, totals and payments, built by hand instead of going through the generic
    /// `Firestore.Encoder()`: `payments` is a `[PaymentMode: Double]` dictionary keyed by an
    /// enum, which the generic encoder mis-encodes as an array.
    static func linesPayload(for sale: Sale) -> [String: Any] {
        var paymentsPayload: [String: Double] = [:]
        for (mode, amount) in sale.payments {
            paymentsPayload[mode.rawValue] = amount
        }

        let itemsPayload: [[String: Any]] = sale.items.map { item in
            var line: [String: Any] = [
                "cat_id": item.categoryId,
                "categoryName": item.categoryName,
                "qty": item.qty,
                "stickerPrice": item.stickerPrice,
                "finalPrice": item.finalPrice,
                "discountType": item.discountType.rawValue
            ]
            if let doneByStaffId = item.doneByStaffId { line["doneByStaffId"] = doneByStaffId }
            if let doneByName = item.doneByName { line["doneByName"] = doneByName }
            if let warrantyMonths = item.warrantyMonths { line["warrantyMonths"] = warrantyMonths }
            if let weight = item.weight { line["weight"] = weight }
            if let unit = item.unit { line["unit"] = unit }
            if let variant = item.variant { line["variant"] = variant }
            return line
        }

        return [
            "items": itemsPayload,
            "subtotal": sale.subtotal,
            "overallDiscountPercent": sale.overallDiscountPercent,
            "overallDiscountAmount": sale.overallDiscountAmount,
            "roundOff": sale.roundOff,
            "netPayable": sale.netPayable,
            "payments": paymentsPayload
        ]
    }
}

private extension SaleService {
    func sales(since lastSync: Date? = nil, for orgId: String) async throws -> [Sale] {
        var query = StoreQuery.all
        if let lastSync = lastSync {
            // New sales match on `timestamp`; edits and cancellations bump `updatedAt` /
            // `serverUpdatedAt`, so they reach other devices too.
            query = StoreQuery(conditions: [
                .greaterThan(field: "timestamp", date: lastSync),
                .greaterThan(field: "updatedAt", date: lastSync),
                .greaterThan(field: "serverUpdatedAt", date: lastSync)
            ], matchAny: true)
        }
        logger.debug("Fetching Sales for Org: \(orgId)")
        let records = try await store.fetch(Sale.self, collection: .orgPath(orgId, .sales), query: query)
        logger.info("Fetched \(records.count) Sales")
        return records
    }
}
