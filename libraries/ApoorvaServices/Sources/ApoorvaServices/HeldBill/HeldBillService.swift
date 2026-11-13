//
//  HeldBillService.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaModels
import ApoorvaLogging

private let logger = AppLogger(category: .network)

public protocol HeldBillServiceProtocol: Sendable {

    func getHeldBills(for orgId: String) async throws -> [HeldBill]
    func getHeldBills(since lastSync: Date, for orgId: String) async throws -> [HeldBill]
    func addHeldBill(_ heldBill: HeldBill, for orgId: String) async throws
    func updateHeldBill(_ heldBill: HeldBill, for orgId: String) async throws
    func deleteHeldBill(id: String, for orgId: String) async throws
}


public final class HeldBillService: HeldBillServiceProtocol {

    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func getHeldBills(for orgId: String) async throws -> [HeldBill] {
        try await heldBills(for: orgId)
    }

    public func getHeldBills(since lastSync: Date, for orgId: String) async throws -> [HeldBill] {
        try await heldBills(since: lastSync, for: orgId)
    }

    public func addHeldBill(_ heldBill: HeldBill, for orgId: String) async throws {
        try store.set(heldBill, path: documentPath(heldBill.id, orgId: orgId))
    }

    public func updateHeldBill(_ heldBill: HeldBill, for orgId: String) async throws {
        var updatedBill = heldBill
        updatedBill.updatedAt = Date()
        try store.set(updatedBill, path: documentPath(heldBill.id, orgId: orgId), merge: true)
    }

    public func deleteHeldBill(id: String, for orgId: String) async throws {
        // Soft-delete to keep offline sync working via the isDeleted flag
        try await store.updateData([
            "isDeleted": true,
            "updatedAt": Date()
        ], path: documentPath(id, orgId: orgId))
    }
}

private extension HeldBillService {
    func documentPath(_ id: String, orgId: String) -> String {
        "\(String.orgPath(orgId, .heldBills))/\(id)"
    }

    func heldBills(since lastSync: Date? = nil, for orgId: String) async throws -> [HeldBill] {
        var query = StoreQuery.all
        if let lastSync = lastSync {
            query = StoreQuery(conditions: [.greaterThan(field: "updatedAt", date: lastSync)])
        }
        logger.debug("Fetching Held Bills for Org: \(orgId)")
        let records = try await store.fetch(HeldBill.self, collection: .orgPath(orgId, .heldBills), query: query)
        logger.info("Fetched \(records.count) Held Bills")
        return records
    }
}
