//
//  CustomerLocalStorage.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL
import ApoorvaLogging

private let logger = AppLogger(category: .storage)

public final actor CustomerLocalStorage: CustomerStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getCustomers() async throws -> [Customer] {
        do {
            let allCustomers: [Customer] = try await database.withContext { context in
                try context.fetchAll(Customer.self)
            }
            return allCustomers.filter { !$0.isDeleted }.sorted { $0.name < $1.name }
        } catch {
            logger.error("SQL Error\(error.localizedDescription)")
            return []
        }
    }

    public func getCustomer(phoneNumber: String) async throws -> Customer? {
        try await database.withContext { context in
            try context.fetch(Customer.self, primaryKeys: [.text(phoneNumber)])
        }
    }

    public func getCustomer(name: String) async throws -> Customer? {
        try await database.withContext { context in
            try context.fetchAll(Customer.self, where: Customer.nameCol.equals(SQLValue(name))).first
        }
    }

    public func saveCustomer(customer: Customer) async throws {
        try await database.withContext { context in
            try context.insert(customer, upsert: true)
        }
    }

    public func updateCustomer(customer: Customer) async throws {
        try await database.withContext { context in
            try context.insert(customer, upsert: true)
        }
    }

    public func deleteCustomer(phoneNumber: String) async throws {
        try await database.withContext { context in
            try context.delete(Customer.self, where: Customer.phoneCol.equals(SQLValue(phoneNumber)))
        }
    }

    /// `id` is the customer's phone number (see `Customer.id`).
    public func markAsDeleted(id: String) async throws {
        guard var customer = try await getCustomer(phoneNumber: id) else { return }
        customer.isDeleted = true
        customer.updatedAt = Date().timeIntervalSince1970
        try await database.withContext { context in
            try context.insert(customer, upsert: true)
        }
    }

    public func saveCustomers(customers: [Customer]) async throws {
        guard !customers.isEmpty else { return }
        try await database.withContext { context in
            try context.transaction {
                for customer in customers {
                    try context.insert(customer, upsert: true)
                }
            }
        }
    }
}
