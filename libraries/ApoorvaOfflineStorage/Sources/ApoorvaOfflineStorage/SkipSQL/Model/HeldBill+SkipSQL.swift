//
//  HeldBill+SkipSQL.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 08/11/26.
//

import ApoorvaModels
import ApoorvaUtilities
import SkipSQL

extension HeldBill: @retroactive SQLCodable {

    public static var table: SQLTable {
        SQLTable(
            name: "HeldBill",
            columns: [
                idCol,
                customerNameCol,
                customerPhoneCol,
                itemsCol,
                totalCol,
                createdAtCol,
                updatedAtCol,
                isDeletedCol
            ]
        )
    }

    public init(row: SQLRow, context: SQLContext) throws {
        let id = try Self.idCol.textValueRequired(in: row)
        let customerName = try Self.customerNameCol.textValueRequired(in: row)
        let customerPhone = try Self.customerPhoneCol.textValueRequired(in: row)
        let items = try Self.itemsCol.textValueRequired(in: row)
        let total = try Self.totalCol.realValueRequired(in: row)
        let createdAt = try Self.createdAtCol.realValueRequired(in: row)
        let updatedAt = Self.updatedAtCol.realValue(in: row)
        let isDeleted = try Self.isDeletedCol.longValueRequired(in: row)

        self.init(id: id,
                  customerName: customerName,
                  customerPhone: customerPhone,
                  items: items.decodeJSON(as: [CartItem].self) ?? [],
                  total: total,
                  createdAt: createdAt.date,
                  updatedAt: updatedAt?.date,
                  isDeleted: isDeleted.boolValue)
    }

    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.idCol] = SQLValue(self.id)
        row[Self.customerNameCol] = SQLValue(self.customerName)
        row[Self.customerPhoneCol] = SQLValue(self.customerPhone)
        row[Self.itemsCol] = SQLValue(self.items.string)
        row[Self.totalCol] = SQLValue(self.total)
        row[Self.createdAtCol] = SQLValue(self.createdAt.timeIntervalSince1970)
        if let date = self.updatedAt {
            row[Self.updatedAtCol] = .real(date.timeIntervalSince1970)
        } else {
            row[Self.updatedAtCol] = .null
        }
        row[Self.isDeletedCol] = SQLValue(self.isDeleted.intValue)
    }

    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let customerNameCol = SQLColumn(name: "customerName", type: .text)
    public static let customerPhoneCol = SQLColumn(name: "customerPhone", type: .text)
    public static let itemsCol = SQLColumn(name: "items", type: .text) // Serializes JSON arrays automatically
    public static let totalCol = SQLColumn(name: "total", type: .real)
    public static let createdAtCol = SQLColumn(name: "createdAt", type: .real)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .long)
}
