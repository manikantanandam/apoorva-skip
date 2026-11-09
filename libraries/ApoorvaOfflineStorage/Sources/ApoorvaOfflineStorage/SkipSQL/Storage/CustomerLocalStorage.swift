//
//  CustomerLocalStorage.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL

public final actor CustomerLocalStorage: CustomerStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getCustomers() throws -> [Customer] {
        do {
            let allCustomers: [Customer] = try database.context.fetchAll(Customer.self)
            return allCustomers.filter { !$0.isDeleted }.sorted { $0.name < $1.name }
        } catch {
            print("SQL Error \(error.localizedDescription)")
            return []
        }
    }

    public func getCustomer(phoneNumber: String) throws -> Customer? {
        try database.context.fetch(Customer.self, primaryKeys: [.text(phoneNumber)])
    }

    public func getCustomer(name: String) throws -> Customer? {
        try database.context.fetchAll(Customer.self, where: Customer.nameCol.equals(SQLValue(name))).first
    }

    public func saveCustomer(customer: Customer) throws {
        try database.context.insert(customer, upsert: true)
    }

    public func updateCustomer(customer: Customer) throws {
        try database.context.insert(customer, upsert: true)
    }

    public func deleteCustomer(phoneNumber: String) throws {
        try database.context.delete(Customer.self, where: Customer.phoneCol.equals(SQLValue(phoneNumber)))
    }

    /// `id` is the customer's phone number (see `Customer.id`).
    public func markAsDeleted(id: String) throws {
        guard var customer = try getCustomer(phoneNumber: id) else { return }
        customer.isDeleted = true
        customer.updatedAt = Date().timeIntervalSince1970
        try database.context.insert(customer, upsert: true)
    }

    public func saveCustomers(customers: [Customer]) throws {
        guard !customers.isEmpty else { return }
        try database.context.transaction {
            for customer in customers {
                try database.context.insert(customer, upsert: true)
            }
        }
    }
}
