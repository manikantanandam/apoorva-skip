//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/07/26.
//

import GRDB
import ApoorvaModels
import Foundation

public typealias Category = ApoorvaModels.InventoryItem

public extension AppDatabase {
    
    func getLastSyncDate(for collection: String) async throws -> Date? {
        try await dbPool.read { db in
            let request = SQLRequest<Date>(sql: "SELECT lastSyncTimestamp FROM SyncState WHERE collectionName = ?", arguments: [collection])
            return try request.fetchOne(db)
        }
    }
    
    func updateSyncDate(_ date: Date, for collection: String) async throws {
        try await dbPool.write { db in
            try db.execute(sql: "INSERT OR REPLACE INTO SyncState (collectionName, lastSyncTimestamp) VALUES (?, ?)", arguments: [collection, date])
        }
    }
    
    func upsertSales(_ sales: [Sale]) async throws {
        try await dbPool.write { db in
            // FIX: Add 'var' here so GRDB is allowed to mutate the struct if needed
            for var sale in sales {
                if sale.isDeleted {
                    try sale.delete(db)
                } else {
                    try sale.save(db)
                }
            }
        }
    }
    
    func upsertCustomers(_ customers: [Customer]) async throws {
            try await dbPool.write { db in
                for var customer in customers {
                    if customer.isDeleted { try customer.delete(db) }
                    else { try customer.save(db) }
                }
            }
        }
        
    func upsertInventory(_ items: [ApoorvaModels.InventoryItem]) async throws {
            try await dbPool.write { db in
                for var item in items {
                    if item.isDeleted { try item.delete(db) }
                    else { try item.save(db) }
                }
            }
        }
    
    func upsertCategories(_ categories: [Category]) async throws {
            try await dbPool.write { db in
                for var category in categories {
                    if category.isDeleted {
                        try category.delete(db)
                    } else {
                        try category.save(db)
                    }
                }
            }
        }
    
    func getTotalRevenueForToday() async throws -> Double {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return try await dbPool.read { db in
            let revenue = try Double.fetchOne(
                db,
                sql: "SELECT SUM(netPayable) FROM Sale WHERE timestamp >= ? AND isDeleted = 0",
                arguments: [startOfDay]
            )
            return revenue ?? 0.0
        }
    }
    
    func getAllSales() async throws -> [Sale] {
            try await dbPool.read { db in
                // Fetch all non-deleted sales, sorted by newest first
                try Sale.fetchAll(
                    db,
                    sql: "SELECT * FROM Sale WHERE isDeleted = 0 ORDER BY timestamp DESC"
                )
            }
        }
    
    func getAllCustomers() async throws -> [Customer] {
            try await dbPool.read { db in
                try Customer.fetchAll(
                    db,
                    sql: "SELECT * FROM Customer WHERE isDeleted = 0"
                )
            }
        }
        
        func getAllCategories() async throws -> [Category] {
            try await dbPool.read { db in
                try Category.fetchAll(
                    db,
                    sql: "SELECT * FROM Category WHERE isDeleted = 0"
                )
            }
        }
    
    // MARK: - Cashflow Operations
        
        func upsertCashflowTransactions(_ transactions: [CashflowTransaction]) async throws {
            try await dbPool.write { db in
                for transaction in transactions {
                    if transaction.isDeleted { try transaction.delete(db) }
                    else { try transaction.save(db) }
                }
            }
        }
        
        func getAllCashflowTransactions() async throws -> [CashflowTransaction] {
            try await dbPool.read { db in
                try CashflowTransaction.fetchAll(
                    db,
                    sql: "SELECT * FROM CashflowTransaction WHERE isDeleted = 0 ORDER BY timestamp DESC"
                )
            }
        }
        
        func getCurrentBalances() async throws -> (cash: Double, upi: Double, total: Double) {
            try await dbPool.read { db in
                let cashCredit = try Double.fetchOne(db, sql: "SELECT SUM(amount) FROM CashflowTransaction WHERE isDeleted = 0 AND transactionType = 'credit' AND paymentMode = 'cash'") ?? 0.0
                let cashDebit = try Double.fetchOne(db, sql: "SELECT SUM(amount) FROM CashflowTransaction WHERE isDeleted = 0 AND transactionType = 'debit' AND paymentMode = 'cash'") ?? 0.0
                
                let upiCredit = try Double.fetchOne(db, sql: "SELECT SUM(amount) FROM CashflowTransaction WHERE isDeleted = 0 AND transactionType = 'credit' AND paymentMode = 'upi'") ?? 0.0
                let upiDebit = try Double.fetchOne(db, sql: "SELECT SUM(amount) FROM CashflowTransaction WHERE isDeleted = 0 AND transactionType = 'debit' AND paymentMode = 'upi'") ?? 0.0
                
                let totalCash = cashCredit - cashDebit
                let totalUPI = upiCredit - upiDebit
                
                return (cash: totalCash, upi: totalUPI, total: totalCash + totalUPI)
            }
        }
    
    
}
