//
//  HeldBillLocalStorage.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaModels
import ApoorvaUtilities
import SkipSQL
import ApoorvaLogging

private let logger = AppLogger(category: .storage)

public final actor HeldBillLocalStorage: HeldBillStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getHeldBills() async throws -> [HeldBill] {
        do {
            let allHeldBills: [HeldBill] = try await database.withContext { context in
                try context.fetchAll(HeldBill.self)
            }
            return allHeldBills.filter { !$0.isDeleted }.sorted()
        } catch let error {
            if let error = error as? SQLError {
                logger.error("SQL Error\(error.localizedDescription)")
            }
            return []
        }
    }

    public func getHeldBill(id: String) async throws -> HeldBill? {
        try await database.withContext { context in
            try context.fetch(HeldBill.self, primaryKeys: [.text(id)])
        }
    }

    public func saveHeldBill(heldBill: HeldBill) async throws {
        try await database.withContext { context in
            try context.insert(heldBill)
        }
    }

    public func updateHeldBill(heldBill: HeldBill) async throws {
        let query = """
        UPDATE \(HeldBill.table.name)
        SET customerName = ?, customerPhone = ?, items = ?, total = ?, createdAt = ?, updatedAt = ?, isDeleted = ?
        WHERE id = ?;
        """

        let updatedAt: SQLValue
        if let _updatedAt = heldBill.updatedAt {
            updatedAt = .real(_updatedAt.timeIntervalSince1970)
        } else {
            updatedAt = .null
        }

        try await database.withContext { context in
            try context.exec(sql: query, parameters: [
                .text(heldBill.customerName),
                .text(heldBill.customerPhone),
                .text(heldBill.items.string),
                .real(heldBill.total),
                .real(heldBill.createdAt.timeIntervalSince1970),
                updatedAt,
                .long(heldBill.isDeleted.int64Value),
                .text(heldBill.id)
            ])
        }
    }

    public func deleteHeldBill(id: String) async throws {
        let query = "DELETE FROM \(HeldBill.table.name) WHERE id = ?;"
        try await database.withContext { context in
            try context.exec(sql: query, parameters: [.text(id)])
        }
    }

    public func markAsDeleted(id: String) async throws {
        let query = "UPDATE \(HeldBill.table.name) SET isDeleted = 1, updatedAt = ? WHERE id = ?;"
        try await database.withContext { context in
            try context.exec(sql: query, parameters: [
                .real(Date().timeIntervalSince1970),
                .text(id)
            ])
        }
    }

    public func saveHeldBills(heldBills: [HeldBill]) async throws {
        guard !heldBills.isEmpty else { return }

        let query = """
        INSERT OR REPLACE INTO \(HeldBill.table.name) (
            id, customerName, customerPhone, items, total, createdAt, updatedAt, isDeleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        do {
            try await database.withContext { context in
                try context.transaction {
                    for heldBill in heldBills {
                        let updatedAt: SQLValue
                        if let _updatedAt = heldBill.updatedAt {
                            updatedAt = .real(_updatedAt.timeIntervalSince1970)
                        } else {
                            updatedAt = .null
                        }

                        try context.exec(sql: query, parameters: [
                            .text(heldBill.id),
                            .text(heldBill.customerName),
                            .text(heldBill.customerPhone),
                            .text(heldBill.items.string),
                            .real(heldBill.total),
                            .real(heldBill.createdAt.timeIntervalSince1970),
                            updatedAt,
                            .long(heldBill.isDeleted.int64Value)
                        ])
                    }
                }
            }
        } catch {
            if let error = error as? SQLError {
                logger.error("Saving held bills failed: \(error.msg)")
            }
            throw error
        }
    }
}
