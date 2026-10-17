//
//  CashflowStorage.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

public final class CashflowTransactionLocalStorage: CashflowTransactionStorageProtocol {
    
    private let database: SkipSqlDatabase
    
    public init(database: SkipSqlDatabase) {
        self.database = database
    }
    
    public func getCashflowTransactions() throws -> [CashflowTransaction] {
        do {
            let allCashflowTransactions: [CashflowTransaction] = try database.context.fetchAll(CashflowTransaction.self)
            // Assuming CashflowTransaction conforms to Comparable for sorted(), otherwise remove .sorted() or provide a closure
            return allCashflowTransactions
        } catch let error {
            if let error = error as? SQLError {
                print("SQL Error \(error.localizedDescription)")
            }
            return []
        }
    }
    
    public func getCashflowTransaction(id: String) throws -> CashflowTransaction? {
        return try database.context.fetch(CashflowTransaction.self, primaryKeys: [.text(id)])
    }
    
    public func saveCashflowTransaction(transaction: CashflowTransaction) throws {
        // skip-sql natively handles inserting SQLCodable types
        try database.context.insert(transaction)
    }
    
    public func updateCashflowTransaction(transaction: CashflowTransaction) throws {
        let query = """
        UPDATE \(CashflowTransaction.table.name)
        SET timestamp = ?, particulars = ?, amount = ?, transactionType = ?, paymentMode = ?, category = ?, subCategory = ?, person = ?, isDeleted = ?, updatedAt = ?
        WHERE id = ?;
        """
        
        let subCategory: SQLValue
        if let _subCategory = transaction.subCategory {
            subCategory = .text(_subCategory.rawValue)
        } else {
            subCategory = .null
        }
        
        let person: SQLValue
        if let _person = transaction.person {
            person = .text(_person)
        } else {
            person = .null
        }

        
        try database.context.exec(sql: query, parameters: [
            .real(transaction.timestamp.timeIntervalSince1970),
            .text(transaction.particulars),
            .real(transaction.amount),
            .text(transaction.transactionType.rawValue),
            .text(transaction.paymentMode.rawValue),
            .text(transaction.category.rawValue),
            subCategory,
            person,
            .long(transaction.isDeleted.int64Value),
            .real(transaction.updatedAt.timeIntervalSince1970),
            .text(transaction.id)
        ])
    }
    
    public func deleteCashflowTransaction(id: String) throws {
        let query = "DELETE FROM \(CashflowTransaction.table.name) WHERE id = ?;"
        
        try database.context.exec(sql: query, parameters: [.text(id)])
    }
    
    public func markAsDeleted(id: String) throws {
        let query = "UPDATE \(CashflowTransaction.table.name) SET isDeleted = 1, updatedAt = ? WHERE id = ?;"
        
        try database.context.exec(sql: query, parameters: [
            .real(Date().timeIntervalSince1970),
            .text(id)
        ])
    }
    
    public func saveCashflowTransactions(transactions: [CashflowTransaction]) throws {
        guard !transactions.isEmpty else { return }
        
        let query = """
        INSERT OR REPLACE INTO \(CashflowTransaction.table.name) (
            id, timestamp, particulars, amount, transactionType, paymentMode, category, subCategory, person, isDeleted, updatedAt
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        try database.context.exec(sql: "BEGIN TRANSACTION;")
        
        do {
            for transaction in transactions {
                try database.context.exec(sql: query, parameters: [
                    .text(transaction.id),
                    .real(transaction.timestamp.timeIntervalSince1970),
                    .text(transaction.particulars),
                    .real(transaction.amount),
                    .text(transaction.transactionType.rawValue),
                    .text(transaction.paymentMode.rawValue),
                    .text(transaction.category.rawValue),
                    transaction.subCategory != nil ? .text(transaction.subCategory!.rawValue) : .null,
                    transaction.person != nil ? .text(transaction.person!) : .null,
                    .long(transaction.isDeleted ? 1 : 0),
                    .real(transaction.updatedAt.timeIntervalSince1970)
                ])
            }
            try database.context.exec(sql: "COMMIT;")
        } catch {
            try? database.context.exec(sql: "ROLLBACK;")
            if let error = error as? SQLError {
                print("Saving cashflow data failed: \(error.msg)")
            }
            throw error
        }
    }
}
