//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import ApoorvaModels
import SkipSQL

extension Customer: @retroactive SQLCodable {
    
    public static var table: SQLTable {
        SQLTable(
            name: "Customer",
            columns: [
                phoneCol,
                nameCol,
                createdAtCol,
                lastPurchaseDateCol,
                totalSalesCol,
                totalAmountSpentCol,
                updatedAtCol,
                isDeletedCol
            ]
        )
    }
    
    public init(row: SQLRow, context: SQLContext) throws {
        let phone = try Self.phoneCol.textValueRequired(in: row)
        let name = try Self.nameCol.textValueRequired(in: row)
        let createdAt = try Self.createdAtCol.realValueRequired(in: row)
        let lastPurchaseDate = try Self.lastPurchaseDateCol.realValueRequired(in: row)
        let totalSales = try Self.totalSalesCol.longValueRequired(in: row)
        let totalAmountSpent = try Self.totalAmountSpentCol.realValueRequired(in: row)
        let updatedAt = try Self.updatedAtCol.realValueRequired(in: row)
        let isDeleted = try Self.isDeletedCol.longValueRequired(in: row)
        
        self.init(name: name,
                  phone: phone,
                  createdAt: createdAt,
                  lastPurchaseDate: lastPurchaseDate,
                  totalSales: totalSales.intValue,
                  totalAmountSpent: totalAmountSpent,
                  updatedAt: updatedAt,
                  isDeleted: isDeleted.boolValue)
    }
    
    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.nameCol] = SQLValue(self.name)
        row[Self.phoneCol] = SQLValue(self.phone)
        row[Self.createdAtCol] = SQLValue(self.createdAt)
        // 1. Safe Optional Binding
        if let date = self.lastPurchaseDate {
            row[Self.lastPurchaseDateCol] = .real(date)
        } else {
            row[Self.lastPurchaseDateCol] = .null
        }
        row[Self.totalSalesCol] = SQLValue(self.totalSales)
        row[Self.totalAmountSpentCol] = SQLValue(self.totalAmountSpent)
        row[Self.updatedAtCol] = SQLValue(self.updatedAt)
        row[Self.isDeletedCol] = SQLValue(self.isDeleted.intValue)
    }
    
    
    public static let phoneCol = SQLColumn(name: "phone", type: .text, primaryKey: true)
    public static let nameCol = SQLColumn(name: "name", type: .text)
    public static let createdAtCol = SQLColumn(name: "createdAt", type: .real)
    public static let lastPurchaseDateCol = SQLColumn(name: "lastPurchaseDate", type: .real)
    public static let totalSalesCol = SQLColumn(name: "totalSales", type: .long)
    public static let totalAmountSpentCol = SQLColumn(name: "totalAmountSpent", type: .real)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .long)
}
