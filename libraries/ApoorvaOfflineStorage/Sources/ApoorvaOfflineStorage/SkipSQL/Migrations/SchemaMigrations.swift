//
//  SchemaMigrations.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL

/// Ordered, append-only schema steps run by `SQLContext.migrate` (tracked in `PRAGMA user_version`).
/// Never edit or reorder a step that has shipped — add a new one at the end.
enum SchemaMigrations {
    static var all: [(SQLContext) throws -> Void] { [
        // v1: baseline. Idempotent, so installs from before migrations (user_version 0) pass through.
        { context in
            try context.createTableIfNotExists(InventoryItem.self)
            try context.createTableIfNotExists(SyncState.self)
            try context.createTableIfNotExists(Customer.self)
            try context.createTableIfNotExists(Sale.self)
            try context.createTableIfNotExists(CashflowTransaction.self)
            try context.createTableIfNotExists(DailyCashflowSummary.self)
            try context.createTableIfNotExists(Organization.self)
            try context.createTableIfNotExists(HeldBill.self)
        },
        // v2: new optional columns, generic org document cache, and a full sales re-sync
        // (legacy sales could collapse into one row before ids were read from the doc ID).
        { context in
            for column in Customer.addedColumns {
                try context.addColumnIfNotExists(column, to: Customer.table)
            }
            for column in InventoryItem.addedColumns {
                try context.addColumnIfNotExists(column, to: InventoryItem.table)
            }
            for column in Sale.addedColumns {
                try context.addColumnIfNotExists(column, to: Sale.table)
            }
            try context.createTableIfNotExists(OrgDocumentRecord.self)
            try context.exec(sql: "DELETE FROM \(SyncState.table.name) WHERE entityName = ?", parameters: [.text(Sale.table.name)])
        }
    ] }

    /// Every table this app owns, for "clear local data".
    static let tables: [SQLTable] = [
        InventoryItem.table, SyncState.table, Customer.table, Sale.table,
        CashflowTransaction.table, DailyCashflowSummary.table, Organization.table,
        HeldBill.table, OrgDocumentRecord.table
    ]
}
