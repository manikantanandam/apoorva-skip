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
