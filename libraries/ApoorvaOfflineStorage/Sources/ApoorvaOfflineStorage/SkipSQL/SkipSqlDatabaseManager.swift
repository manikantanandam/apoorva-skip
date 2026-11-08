//
//  SkipSqlDatabaseManager.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

@preconcurrency import SkipSQL
import Foundation
import ApoorvaModels

public final class SkipSqlDatabase: @unchecked Sendable {
    public let context: SQLContext

    public init(filepath: String) throws {
        self.context = try SQLContext(
            path: filepath, flags: [.create, .readWrite],
            configuration: .platform
        )
        try migrate()
    }

    /// Brings the schema up to date. Safe to call repeatedly.
    public func migrate() throws {
        try context.migrate(migrations: SchemaMigrations.all)
    }

    public var schemaVersion: Int64 {
        context.userVersion
    }

    /// Deletes all rows from every local table, in place, without touching the file or closing the connection.
    /// Safe to call while the app keeps running (unlike deleting the database file, which requires a restart).
    public func clearAllLocalData() throws {
        try context.transaction {
            for table in SchemaMigrations.tables {
                try context.exec(sql: "DELETE FROM \(table.quotedName())")
            }
        }
    }
}
