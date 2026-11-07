//
//  InventoryItemService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels

public protocol InventoryItemServiceProtocol: Sendable {

    func getInventoryItems(for orgId: String) async throws -> [InventoryItem]
    func getInventoryItems(since lastSync: Date, for orgId: String) async throws -> [InventoryItem]
}


public final class InventoryItemService: InventoryItemServiceProtocol {

    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func getInventoryItems(for orgId: String) async throws -> [InventoryItem] {
        try await inventoryItems(for: orgId)
    }

    public func getInventoryItems(since lastSync: Date, for orgId: String) async throws -> [InventoryItem] {
        try await inventoryItems(since: lastSync, for: orgId)
    }
}

private extension InventoryItemService {
    func inventoryItems(since lastSync: Date? = nil, for orgId: String) async throws -> [InventoryItem] {
        var query = StoreQuery.all
        if let lastSync = lastSync {
            query = StoreQuery(
                conditions: [
                    .greaterThan(field: "updatedAt", date: lastSync),
                    .greaterThan(field: "lastSoldDate", date: lastSync)
                ],
                matchAny: true
            )
        }
        print("🌐 Fetching Inventory for Org: \(orgId)...")
        let records = try await store.fetch(InventoryItem.self, collection: .orgPath(orgId, .inventory), query: query)
        print("✅ Fetched \(records.count) Inventory items.")
        return records
    }
}
