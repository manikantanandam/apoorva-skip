//
//  CashflowStorage.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

public final actor CashflowTransactionLocalStorage: CashflowTransactionStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getCashflowTransactions() async throws -> [CashflowTransaction] {
        do {
            let allCashflowTransactions: [CashflowTransaction] = try await database.withContext { context in
                try context.fetchAll(CashflowTransaction.self)
            }
            // Assuming CashflowTransaction conforms to Comparable for sorted(), otherwise remove .sorted() or provide a closure
            return allCashflowTransactions
        } catch let error {
            if let error = error as? SQLError {
                print("SQL Error \(error.localizedDescription)")
            }
            return []
        }
    }

    public func getCashflowTransaction(id: String) async throws -> CashflowTransaction? {
        try await database.withContext { context in
            try context.fetch(CashflowTransaction.self, primaryKeys: [.text(id)])
        }
    }

    public func saveCashflowTransaction(transaction: CashflowTransaction) async throws {
        // skip-sql natively handles inserting SQLCodable types
        try await database.withContext { context in
            try context.insert(transaction)
        }
    }

    public func updateCashflowTransaction(transaction: CashflowTransaction) async throws {
        let query = """
        UPDATE \(CashflowTransaction.table.name)
        SET timestamp = ?, particulars = ?, amount = ?, transactionType = ?, paymentMode = ?, category = ?, subCategory = ?, person = ?, isDeleted = ?, updatedAt = ?, fromAccountId = ?, toAccountId = ?, timestampInMs = ?, updatedAtInMs = ?
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


        try await database.withContext { context in
            try context.exec(sql: query, parameters: [
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
                .text(transaction.id),
                .text(transaction.fromAccountId),
                .text(transaction.toAccountId),
                .real(transaction.timestampInMs),
                .real(transaction.updatedAtInMs),
            ])
        }
    }

    public func deleteCashflowTransaction(id: String) async throws {
        let query = "DELETE FROM \(CashflowTransaction.table.name) WHERE id = ?;"

        try await database.withContext { context in
            try context.exec(sql: query, parameters: [.text(id)])
        }
    }

    public func markAsDeleted(id: String) async throws {
        let query = "UPDATE \(CashflowTransaction.table.name) SET isDeleted = 1, updatedAt = ? WHERE id = ?;"

        try await database.withContext { context in
            try context.exec(sql: query, parameters: [
                .real(Date().timeIntervalSince1970),
                .text(id)
            ])
        }
    }

    public func saveCashflowTransactions(transactions: [CashflowTransaction]) async throws {
        guard !transactions.isEmpty else { return }

        let query = """
        INSERT OR REPLACE INTO \(CashflowTransaction.table.name) (
            id, timestamp, particulars, amount, transactionType, paymentMode, category, subCategory, person, isDeleted, updatedAt, fromAccountId, toAccountId, timestampInMs, updatedAtInMs
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        do {
            try await database.withContext { context in
                try context.transaction {
                    for transaction in transactions {
                        print("saving transaction locally \(transaction)")
                        try context.exec(sql: query, parameters: [
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
                            .real(transaction.updatedAt.timeIntervalSince1970),
                            .text(transaction.fromAccountId),
                            .text(transaction.toAccountId),
                            .real(transaction.timestampInMs),
                            .real(transaction.updatedAtInMs),
                        ])
                    }
                }
            }
        } catch {
            if let error = error as? SQLError {
                print("Saving cashflow data failed: \(error.msg)")
            }
            throw error
        }
    }
}
