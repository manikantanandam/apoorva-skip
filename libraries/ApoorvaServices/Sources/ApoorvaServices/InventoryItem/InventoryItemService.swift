//
//  InventoryItemService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
import ApoorvaLogging

private let logger = AppLogger(category: .network)

public protocol InventoryItemServiceProtocol: Sendable {

    func getInventoryItems(for orgId: String) async throws -> [InventoryItem]
    func getInventoryItems(since lastSync: Date, for orgId: String) async throws -> [InventoryItem]
    /// Creates or updates an item (merge, explicit fields; never removes legacy fields).
    func upsertInventoryItem(_ item: InventoryItem, for orgId: String) throws
}

public extension InventoryItemServiceProtocol {
    func upsertInventoryItem(_ item: InventoryItem, for orgId: String) throws {}
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

    public func upsertInventoryItem(_ item: InventoryItem, for orgId: String) throws {
        var data: [String: Any] = [
            "id": item.id,
            "name": item.name,
            "currentStock": item.currentStock,
            "billMachineNumber": item.billMachineNumber,
            "isHotkey": item.isHotkey,
            "isDeleted": item.isDeleted,
            "updatedAt": item.updatedAt ?? Date(),
            "serverUpdatedAt": StoreSentinel.serverTimestamp
        ]
        if let lastSoldDate = item.lastSoldDate { data["lastSoldDate"] = lastSoldDate }
        if let barcode = item.barcode { data["barcode"] = barcode }
        if let sellPrice = item.sellPrice { data["sellPrice"] = sellPrice }
        if let costPrice = item.costPrice { data["costPrice"] = costPrice }
        if let wholesalePrice = item.wholesalePrice { data["wholesalePrice"] = wholesalePrice }
        if let categoryId = item.categoryId { data["categoryId"] = categoryId }
        if let unit = item.unit { data["unit"] = unit }
        if let lowStockThreshold = item.lowStockThreshold { data["lowStockThreshold"] = lowStockThreshold }
        if let imageURLs = item.imageURLs { data["imageURLs"] = imageURLs }
        if let designCode = item.designCode { data["designCode"] = designCode }
        if let variantsJSON = item.variantsJSON { data["variantsJSON"] = variantsJSON }
        if let warrantyMonths = item.warrantyMonths { data["warrantyMonths"] = warrantyMonths }
        try store.setData(data, path: "\(String.orgPath(orgId, .inventory))/\(item.id)", merge: true)
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
        logger.debug("Fetching Inventory for Org: \(orgId)")
        let records = try await store.fetch(InventoryItem.self, collection: .orgPath(orgId, .inventory), query: query)
        logger.info("Fetched \(records.count) Inventory items")
        return records
    }
}
