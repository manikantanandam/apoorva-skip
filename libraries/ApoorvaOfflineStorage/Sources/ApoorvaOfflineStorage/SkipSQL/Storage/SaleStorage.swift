//
//  SaleStorage.swift
//  ApoorvaOfflineStorage
//

import Foundation
import ApoorvaModels
import SkipSQL

public final actor SaleLocalStorage: SaleStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getSales() throws -> [Sale] {
        do {
            let allSales: [Sale] = try database.context.fetchAll(Sale.self)
            return allSales.filter { !$0.isDeleted }.sorted()
        } catch {
            print("SQL Error \(error.localizedDescription)")
            return []
        }
    }

    public func getSale(id: String) throws -> Sale? {
        try database.context.fetch(Sale.self, primaryKeys: [.text(id)])
    }

    public func saveSale(sale: Sale) throws {
        try database.context.insert(sale, upsert: true)
    }

    public func updateSale(sale: Sale) throws {
        try database.context.insert(sale, upsert: true)
    }

    public func deleteSale(id: String) throws {
        try database.context.delete(Sale.self, where: Sale.idCol.equals(SQLValue(id)))
    }

    public func markAsDeleted(id: String) throws {
        guard var sale = try getSale(id: id) else { return }
        sale.isDeleted = true
        sale.updatedAt = Date()
        try database.context.insert(sale, upsert: true)
    }

    public func saveSales(sales: [Sale]) throws {
        // Skip docs that decoded without an id instead of letting them overwrite one row.
        let valid = sales.filter { !$0.id.isEmpty }
        guard !valid.isEmpty else { return }
        try database.context.transaction {
            for sale in valid {
                try database.context.insert(sale, upsert: true)
            }
        }
    }
}
