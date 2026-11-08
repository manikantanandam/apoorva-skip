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

public final actor HeldBillLocalStorage: HeldBillStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getHeldBills() throws -> [HeldBill] {
        do {
            let allHeldBills: [HeldBill] = try database.context.fetchAll(HeldBill.self)
            return allHeldBills.filter { !$0.isDeleted }.sorted()
        } catch let error {
            if let error = error as? SQLError {
                print("SQL Error \(error.localizedDescription)")
            }
            return []
        }
    }

    public func getHeldBill(id: String) throws -> HeldBill? {
        return try database.context.fetch(HeldBill.self, primaryKeys: [.text(id)])
    }

    public func saveHeldBill(heldBill: HeldBill) throws {
        try database.context.insert(heldBill)
    }

    public func updateHeldBill(heldBill: HeldBill) throws {
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

        try database.context.exec(sql: query, parameters: [
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

    public func deleteHeldBill(id: String) throws {
        let query = "DELETE FROM \(HeldBill.table.name) WHERE id = ?;"
        try database.context.exec(sql: query, parameters: [.text(id)])
    }

    public func markAsDeleted(id: String) throws {
        let query = "UPDATE \(HeldBill.table.name) SET isDeleted = 1, updatedAt = ? WHERE id = ?;"
        try database.context.exec(sql: query, parameters: [
            .real(Date().timeIntervalSince1970),
            .text(id)
        ])
    }

    public func saveHeldBills(heldBills: [HeldBill]) throws {
        guard !heldBills.isEmpty else { return }

        let query = """
        INSERT OR REPLACE INTO \(HeldBill.table.name) (
            id, customerName, customerPhone, items, total, createdAt, updatedAt, isDeleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        try database.context.exec(sql: "BEGIN TRANSACTION;")

        do {
            for heldBill in heldBills {
                let updatedAt: SQLValue
                if let _updatedAt = heldBill.updatedAt {
                    updatedAt = .real(_updatedAt.timeIntervalSince1970)
                } else {
                    updatedAt = .null
                }

                try database.context.exec(sql: query, parameters: [
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
            try database.context.exec(sql: "COMMIT;")
        } catch {
            try? database.context.exec(sql: "ROLLBACK;")
            if let error = error as? SQLError {
                print("Saving held bills failed: \(error.msg)")
            }
            throw error
        }
    }
}
