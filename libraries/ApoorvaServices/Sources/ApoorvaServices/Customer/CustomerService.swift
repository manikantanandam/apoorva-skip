//
//  CustomerService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels

public protocol CustomerServiceProtocol: Sendable {

    func getCustomers(for orgId: String) async throws -> [Customer]
    func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer]
    func upsertCustomerAfterSale(phone: String, name: String, saleAmount: Double, saleDate: Date, for orgId: String) async throws
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

    /// Creates the customer doc if it's the first sale for this phone number, otherwise bumps
    /// their running stats. Keyed by phone (there's no other stable id on `Customer`).
    public func upsertCustomerAfterSale(phone: String, name: String, saleAmount: Double, saleDate: Date, for orgId: String) async throws {
        guard !phone.isEmpty else { return }

        let path = "\(String.orgPath(orgId, .customers))/\(phone)"
        let existing = try await store.getDocument(path: path)

        if let existing {
            let totalSales = (existing.data["totalSales"] as? Int ?? 0) + 1
            let totalAmountSpent = (existing.data["totalAmountSpent"] as? Double ?? 0.0) + saleAmount
            try await store.updateData([
                "totalSales": totalSales,
                "totalAmountSpent": totalAmountSpent,
                "lastPurchaseDate": saleDate,
                "updatedAt": Date()
            ], path: path)
        } else {
            let payload: [String: Any] = [
                "name": name,
                "phone": phone,
                "createdAt": saleDate,
                "lastPurchaseDate": saleDate,
                "totalSales": 1,
                "totalAmountSpent": saleAmount,
                "updatedAt": Date(),
                "isDeleted": false
            ]
            try store.setData(payload, path: path, merge: false)
        }
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
