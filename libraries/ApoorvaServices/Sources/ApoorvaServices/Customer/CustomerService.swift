//
//  CustomerService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels

public protocol CustomerServiceProtocol: Sendable {

    func getCustomers(for orgId: String) async throws -> [Customer]
    func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer]
}


public final class CustomerService: CustomerServiceProtocol {

    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func getCustomers(for orgId: String) async throws -> [Customer] {
        try await customers(for: orgId)
    }

    public func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer] {
        try await customers(since: lastSync, for: orgId)
    }
}

private extension CustomerService {
    func customers(since lastSync: Date? = nil, for orgId: String) async throws -> [Customer] {
        var query = StoreQuery.all
        if let lastSync = lastSync {
            query = StoreQuery(
                conditions: [
                    .greaterThan(field: "updatedAt", date: lastSync),
                    .greaterThan(field: "lastPurchaseDate", date: lastSync)
                ],
                matchAny: true
            )
        }
        print("🌐 Fetching Customers for Org: \(orgId)...")
        let records = try await store.fetch(Customer.self, collection: .orgPath(orgId, .customers), query: query)
        print("✅ Fetched \(records.count) Customers.")
        return records
    }
}
