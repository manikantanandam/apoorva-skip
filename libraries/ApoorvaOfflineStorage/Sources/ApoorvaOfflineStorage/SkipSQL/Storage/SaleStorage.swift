//
//  SaleStorage.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL
import ApoorvaLogging

private let logger = AppLogger(category: .storage)

public final actor SaleLocalStorage: SaleStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getSales() async throws -> [Sale] {
        do {
            let allSales: [Sale] = try await database.withContext { context in
                try context.fetchAll(Sale.self)
            }
            return allSales.filter { !$0.isDeleted }.sorted()
        } catch {
            logger.error("SQL Error\(error.localizedDescription)")
            return []
        }
    }

    public func getSale(id: String) async throws -> Sale? {
        try await database.withContext { context in
            try context.fetch(Sale.self, primaryKeys: [.text(id)])
        }
    }

    public func saveSale(sale: Sale) async throws {
        try await database.withContext { context in
            try context.insert(sale, upsert: true)
        }
    }

    public func updateSale(sale: Sale) async throws {
        try await database.withContext { context in
            try context.insert(sale, upsert: true)
        }
    }

    public func deleteSale(id: String) async throws {
        try await database.withContext { context in
            try context.delete(Sale.self, where: Sale.idCol.equals(SQLValue(id)))
        }
    }

    public func markAsDeleted(id: String) async throws {
        guard var sale = try await getSale(id: id) else { return }
        sale.isDeleted = true
        sale.updatedAt = Date()
        try await database.withContext { context in
            try context.insert(sale, upsert: true)
        }
    }

    public func saveSales(sales: [Sale]) async throws {
        // Skip docs that decoded without an id instead of letting them overwrite one row.
        let valid = sales.filter { !$0.id.isEmpty }
        guard !valid.isEmpty else { return }
        try await database.withContext { context in
            try context.transaction {
                for sale in valid {
                    try context.insert(sale, upsert: true)
                }
            }
        }
    }
}
