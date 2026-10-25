//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels
@preconcurrency import FirebaseFirestore

public protocol InventoryItemServiceProtocol: Sendable {
    
    func getInventoryItems(for orgId: String) async throws -> [InventoryItem]
    func getInventoryItems(since lastSync: Date, for orgId: String) async throws -> [InventoryItem]
}


public final class InventoryItemService: InventoryItemServiceProtocol {

    private let db = Firestore.firestore()
    
    public init() {}

    public func getInventoryItems(for orgId: String) async throws -> [InventoryItem] {
        try await inventoryItems(for: orgId)
    }
    
    public func getInventoryItems(since lastSync: Date, for orgId: String) async throws -> [InventoryItem] {
        try await inventoryItems(since: lastSync, for: orgId)
    }
}

private extension InventoryItemService {
    func inventoryItems(since lastSync: Date? = nil, for orgId: String) async throws -> [InventoryItem] {
        let baseCollection = db
                .collection(.organizations)
                .document(orgId)
                .collection(.inventory)
                
        var query: Query = baseCollection
            
        if let lastSync = lastSync {
                let timestamp = Timestamp(date: lastSync)
                
                query = baseCollection.whereFilter(
                    Filter.orFilter([
                        Filter.whereField("updatedAt", isGreaterThan: timestamp),
                        Filter.whereField("lastSoldDate", isGreaterThan: timestamp)
                    ])
                )
            }
            
            print("🌐 Fetching Categories for Org: \(orgId)...")
            let snapshot = try await query.getDocuments()
            
            var successfulRecords: [Category] = []
            for document in snapshot.documents {
                do {
                    var record = try document.data(as: Category.self)
                    successfulRecords.append(record)
                } catch { print("❌ Failed to decode Category: \(document.documentID) - \(error)") }
            }
            
            print("✅ Fetched \(successfulRecords.count) Categories.")
            return successfulRecords
        }
}
