//
//  CustomerService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
import ApoorvaLogging

private let logger = AppLogger(category: .network)

public protocol CustomerServiceProtocol: Sendable {

    func getCustomers(for orgId: String) async throws -> [Customer]
    func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer]
    func upsertCustomerAfterSale(phone: String, name: String, saleAmount: Double, saleDate: Date, for orgId: String) async throws
    /// Creates or updates a customer from the customers screens (merge; never removes legacy fields).
    func upsertCustomer(_ customer: Customer, for orgId: String) throws
}

public extension CustomerServiceProtocol {
    func upsertCustomer(_ customer: Customer, for orgId: String) throws {}
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

    public func upsertCustomer(_ customer: Customer, for orgId: String) throws {
        guard !customer.phone.isEmpty else { return }
        var data: [String: Any] = [
            "name": customer.name,
            "phone": customer.phone,
            "createdAt": Date(timeIntervalSince1970: customer.createdAt),
            "updatedAt": Date(),
            "isDeleted": customer.isDeleted,
            "dueBalance": customer.dueBalance,
            "whatsappReceipts": customer.whatsappReceipts,
            "serverUpdatedAt": StoreSentinel.serverTimestamp
        ]
        if let creditLimit = customer.creditLimit { data["creditLimit"] = creditLimit }
        if let birthday = customer.birthday { data["birthday"] = Date(timeIntervalSince1970: birthday) }
        if let priceTier = customer.priceTier { data["priceTier"] = priceTier }
        if let notes = customer.notes { data["notes"] = notes }
        try store.setData(data, path: "\(String.orgPath(orgId, .customers))/\(customer.phone)", merge: true)
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
        logger.debug("Fetching Customers for Org: \(orgId)")
        let records = try await store.fetch(Customer.self, collection: .orgPath(orgId, .customers), query: query)
        logger.info("Fetched \(records.count) Customers")
        return records
    }
}
