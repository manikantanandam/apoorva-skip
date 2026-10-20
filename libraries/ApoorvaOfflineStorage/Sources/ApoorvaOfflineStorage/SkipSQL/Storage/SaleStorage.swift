//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 16/10/26.
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
            return allSales.sorted()
        } catch let error {
            if let error = error as? SQLError {
                print("SQL Error \(error.localizedDescription)")
            }
            
            return []
        }
    }
    
    public func getSale(id: String) throws -> Sale? {
        return try database.context.fetch(Sale.self, primaryKeys: [.text(id)])
    }
    
    public func saveSale(sale: Sale) throws {
        // skip-sql natively handles inserting SQLCodable types
        try database.context.insert(sale)
    }
    
    public func updateSale(sale: Sale) throws {
        let query = """
        UPDATE \(Sale.table.name)
        SET staffId = ?, customerPhone = ?, customerName = ?, items = ?, subtotal = ?, overallDiscountPercent = ?, overallDiscountAmount = ?, roundOff = ?, netPayable = ?, payments = ?, timestamp = ?, source = ?, status = ?, whatsappStatus = ?, updatedAt = ?, isDeleted = ?, overallDiscountAmount = ?
        WHERE id = ?;
        """
        let updatedAt: SQLValue
        if let _updatedAt = sale.updatedAt {
            updatedAt = .real(_updatedAt.timeIntervalSince1970)
        } else {
            updatedAt = .null
        }


        
        // Fix: Use 'sql:' and 'parameters:' labels, and wrap everything in SQLValue
        try database.context.exec(sql: query, parameters: [
            .text(sale.staffId),
            .text(sale.customerPhone),
            .text(sale.customerName),
            .text(sale.items.string),
            .real(sale.subtotal),
            .real(sale.overallDiscountPercent),
            .real(sale.overallDiscountAmount),
            .real(sale.roundOff),
            .real(sale.netPayable),
            .text(sale.payments.string),
            .real(sale.timestamp.timeIntervalSince1970),
            .text(sale.source),
            .text(sale.status),
            .text(sale.whatsappStatus),
            updatedAt,
            .long(sale.isDeleted.int64Value)
        ])
    }
    
    public func deleteSale(id: String) throws {
        let query = "DELETE FROM  \(Sale.table.name) WHERE id = ?;"
        
        // Fix: Explicitly use sql: and parameters: [SQLValue]
        try database.context.exec(sql: query, parameters: [.text(id)])
    }
    
    public func markAsDeleted(id: String) throws {
        let query = "UPDATE  \(Sale.table.name) SET isDeleted = 1, updatedAt = ? WHERE id = ?;"
        
        // Dates are typically stored as .real (timeInterval) or .text in skip-sql
        try database.context.exec(sql: query, parameters: [
            .real(Date().timeIntervalSince1970),
            .text(id)
        ])
    }
    
    public func saveSales(sales: [Sale]) throws {
            guard !sales.isEmpty else { return }
    
        
            let query = """
            INSERT OR REPLACE INTO \(Sale.table.name) (
                id, staffId, customerPhone,  customerName, items, subtotal, overallDiscountPercent, overallDiscountAmount, roundOff, netPayable, payments, timestamp, source, status, whatsappStatus, updatedAt, isDeleted
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            
            try database.context.exec(sql: "BEGIN TRANSACTION;")
            
            do {
                for sale in sales {
                    let updatedAt: SQLValue
                    if let _updatedAt = sale.updatedAt {
                        updatedAt = .real(_updatedAt.timeIntervalSince1970)
                    } else {
                        updatedAt = .null
                    }

                    try database.context.exec(sql: query, parameters: [
                        .text(sale.id),
                        .text(sale.staffId),
                        .text(sale.customerPhone),
                        .text(sale.customerName),
                        .text(sale.items.string),
                        .real(sale.subtotal),
                        .real(sale.overallDiscountPercent),
                        .real(sale.overallDiscountAmount),
                        .real(sale.roundOff),
                        .real(sale.netPayable),
                        .text(sale.payments.string),
                        .real(sale.timestamp.timeIntervalSince1970),
                        .text(sale.source),
                        .text(sale.status),
                        .text(sale.whatsappStatus),
                        updatedAt,
                        .long(sale.isDeleted.int64Value)
                    ])
                }
                try database.context.exec(sql: "COMMIT;")
            } catch {
                try? database.context.exec(sql: "ROLLBACK;")
                if let error = error as? SQLError {
                    print("Saving sales data failed: \(error.msg)")
                }
                throw error
            }
        }
}
