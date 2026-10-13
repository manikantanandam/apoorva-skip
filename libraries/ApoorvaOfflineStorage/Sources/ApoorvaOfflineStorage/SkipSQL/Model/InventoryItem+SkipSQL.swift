//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import ApoorvaModels
import ApoorvaUtilities
import SkipSQL

extension ApoorvaModels.InventoryItem: @retroactive SQLCodable {
    public static var table: SkipSQLCore.SQLTable {
        SQLTable(
            name: "ItemCategory",
            columns: [
                idCol,
                nameCol,
                currentStockCol,
                billMachineNumberCol,
                lastSoldDateCol,
                isHotkeyCol,
                updatedAtCol,
                isDeletedCol
            ]
        )
    }
    
    public init(row: SkipSQLCore.SQLRow, context: SkipSQLCore.SQLContext) throws {
        let id = try Self.idCol.textValueRequired(in: row)
        let name = try Self.nameCol.textValueRequired(in: row)
        let currentStock = try Self.currentStockCol.longValueRequired(in: row)
        let billMachineNumber = try Self.billMachineNumberCol.longValueRequired(in: row)
        let lastSoldDate = Self.lastSoldDateCol.realValue(in: row)
        let isHotkey = try Self.isHotkeyCol.textValueRequired(in: row)
        let updatedAt = Self.updatedAtCol.realValue(in: row)
        let isDeleted = try Self.isDeletedCol.textValueRequired(in: row)
        
        self.init(
            id: id,
            name: name,
            currentStock: currentStock.intValue,
            billMachineNumber: billMachineNumber.intValue,
            lastSoldDate: lastSoldDate?.date,
            isHotkey: isHotkey.boolValue(defaultValue: false),
            updatedAt: updatedAt?.date,
            isDeleted: isDeleted.boolValue(defaultValue: false)
        )
    }
    
    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.idCol] = SQLValue(self.id)
        print("Encoding \(self.id)")
        print("idCol \(Self.idCol)")
        row[Self.nameCol] = SQLValue(self.name)
        row[Self.currentStockCol] = SQLValue(self.currentStock)
        row[Self.billMachineNumberCol] = SQLValue(self.billMachineNumber)
        // 1. Safe Optional Binding
        if let date = self.lastSoldDate {
            row[Self.lastSoldDateCol] = .real(date.timeIntervalSince1970)
        } else {
            row[Self.lastSoldDateCol] = .null
        }

        row[Self.isHotkeyCol] = SQLValue(self.isHotkey.stringValue)
        if let date = self.lastSoldDate {
            row[Self.updatedAtCol] = .real(date.timeIntervalSince1970)
        } else {
            row[Self.updatedAtCol] = .null
        }
        row[Self.isDeletedCol] = SQLValue(self.isDeleted.stringValue)
    }
    
    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let nameCol = SQLColumn(name: "name", type: .text)
    public static let currentStockCol = SQLColumn(name: "currentStock", type: .long)
    public static let billMachineNumberCol = SQLColumn(name: "billMachineNumber", type: .long)
    public static let lastSoldDateCol = SQLColumn(name: "lastSoldDate", type: .real)
    public static let isHotkeyCol = SQLColumn(name: "isHotkey", type: .text)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .text)
}
