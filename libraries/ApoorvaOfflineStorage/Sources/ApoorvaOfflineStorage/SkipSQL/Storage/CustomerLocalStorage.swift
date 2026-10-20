//
//  CategoryLocalStorage.swift
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
            return allCustomers.sorted { $0.name < $1.name }
        } catch let error {
            if let error = error as? SQLError {
                print("SQL Error \(error.localizedDescription)")
            }
            
            return []
        }
    }
    
    public func getCustomer(phoneNumber: String) throws -> Customer? {
        return try database.context.fetch(Customer.self, primaryKeys: [.text(phoneNumber)])
    }
    public func getCustomer(name: String) throws -> Customer? {
        return try database.context.fetch(Customer.self, primaryKeys: [.text(name)])
    }
    
    public func saveCustomer(customer: Customer) throws {
        // skip-sql natively handles inserting SQLCodable types
        try database.context.insert(customer)
    }
    
    public func updateCustomer(customer: Customer) throws {
        let query = """
        UPDATE \(Customer.table.name)
        SET name = ?, createdAt = ?, lastPurchaseDate = ?, totalSales = ?, totalAmountSpent = ?, updatedAt = ?, isDeleted = ?
        WHERE phone = ?;
        """
        
        // Convert Swift types to SQLite compatible Int64 and Double types
        let name = customer.name
        let createdAt = customer.createdAt
        let totalSales = customer.totalSales
        let totalAmountSpent = customer.totalAmountSpent
//        let updatedAt = customer.updatedAt
        let isDeletedInt64: Int64 = customer.isDeleted.int64Value
        

        let lastPurchaseDate: SQLValue
        if let _lastPurchaseDate = customer.lastPurchaseDate {
            lastPurchaseDate = .real(_lastPurchaseDate)
        } else {
            lastPurchaseDate = .null
        }
        
        let updatedAt: SQLValue
        if let _updatedAt = customer.updatedAt {
            updatedAt = .real(_updatedAt)
        } else {
            updatedAt = .null
        }


        
        // Fix: Use 'sql:' and 'parameters:' labels, and wrap everything in SQLValue
        try database.context.exec(sql: query, parameters: [
            .text(name),
            .real(createdAt),
            lastPurchaseDate,
            .long(totalSales.int64Value),
            .real(totalAmountSpent),
            updatedAt,
            .long(isDeletedInt64),
        ])
    }
    
    public func deleteCustomer(phoneNumber: String) throws {
        let query = "DELETE FROM  \(Customer.table.name) WHERE id = ?;"
        
        // Fix: Explicitly use sql: and parameters: [SQLValue]
        try database.context.exec(sql: query, parameters: [.text(phoneNumber)])
    }
    
    public func markAsDeleted(id: String) throws {
        let query = "UPDATE  \(Customer.table.name) SET isDeleted = 1, updatedAt = ? WHERE id = ?;"
        
        // Dates are typically stored as .real (timeInterval) or .text in skip-sql
        try database.context.exec(sql: query, parameters: [
            .real(Date().timeIntervalSince1970),
            .text(id)
        ])
    }
    
    public func saveCustomers(customers: [Customer]) throws {
            guard !customers.isEmpty else { return }
        
            let query = """
            INSERT OR REPLACE INTO \(Customer.table.name) (
                name, phone,  createdAt, lastPurchaseDate, totalSales, totalAmountSpent, updatedAt, isDeleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
            
            try database.context.exec(sql: "BEGIN TRANSACTION;")
            
            do {
                for customer in customers {
                    // Convert Swift types to SQLite compatible Int64 and Double types
                    let name = customer.name
                    let phone = customer.phone
                    let createdAt = customer.createdAt
                    let totalSales = customer.totalSales
                    let totalAmountSpent = customer.totalAmountSpent
//                    let updatedAt = customer.updatedAt
                    let isDeletedInt64: Int64 = customer.isDeleted.int64Value
                    

                    let lastPurchaseDate: SQLValue
                    if let _lastPurchaseDate = customer.lastPurchaseDate {
                        lastPurchaseDate = .real(_lastPurchaseDate)
                    } else {
                        lastPurchaseDate = .null
                    }
                    
                    let updatedAt: SQLValue
                    if let _updatedAt = customer.updatedAt {
                        updatedAt = .real(_updatedAt)
                    } else {
                        updatedAt = .null
                    }

                    try database.context.exec(sql: query, parameters: [
                        .text(name),
                        .text(phone),
                        .real(createdAt),
                        lastPurchaseDate,
                        .long(totalSales.int64Value),
                        .real(totalAmountSpent),
                        updatedAt,
                        .long(isDeletedInt64),
                    ])
                }
                try database.context.exec(sql: "COMMIT;")
            } catch {
                try? database.context.exec(sql: "ROLLBACK;")
                throw error
            }
        }
}
