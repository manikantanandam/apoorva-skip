//
//  InventoryItem+SkipSQL.swift
//  ApoorvaOfflineStorage
//

import ApoorvaModels
import ApoorvaUtilities
import SkipSQL

extension ApoorvaModels.InventoryItem: @retroactive SQLCodable {
    public static var table: SkipSQLCore.SQLTable {
        SQLTable(name: "ItemCategory", columns: baseColumns + addedColumns)
    }

    static let baseColumns: [SQLColumn] = [
        idCol, nameCol, currentStockCol, billMachineNumberCol, lastSoldDateCol, isHotkeyCol, updatedAtCol, isDeletedCol
    ]

    static let addedColumns: [SQLColumn] = [
        barcodeCol, sellPriceCol, costPriceCol, wholesalePriceCol, categoryIdCol, unitCol,
        lowStockThresholdCol, imageURLsCol, designCodeCol, variantsJSONCol, warrantyMonthsCol
    ]

    public init(row: SkipSQLCore.SQLRow, context: SkipSQLCore.SQLContext) throws {
        self.init(
            id: try Self.idCol.textValueRequired(in: row),
            name: Self.nameCol.textValue(in: row) ?? "",
            currentStock: Int(Self.currentStockCol.longValue(in: row) ?? 0),
            billMachineNumber: Int(Self.billMachineNumberCol.longValue(in: row) ?? 0),
            lastSoldDate: Self.lastSoldDateCol.realValue(in: row)?.date,
            // Legacy rows store these booleans as TEXT "true"/"false".
            isHotkey: (Self.isHotkeyCol.textValue(in: row) ?? "false").boolValue(defaultValue: false),
            updatedAt: Self.updatedAtCol.realValue(in: row)?.date,
            isDeleted: (Self.isDeletedCol.textValue(in: row) ?? "false").boolValue(defaultValue: false),
            barcode: Self.barcodeCol.textValue(in: row),
            sellPrice: Self.sellPriceCol.realValue(in: row),
            costPrice: Self.costPriceCol.realValue(in: row),
            wholesalePrice: Self.wholesalePriceCol.realValue(in: row),
            categoryId: Self.categoryIdCol.textValue(in: row),
            unit: Self.unitCol.textValue(in: row),
            lowStockThreshold: Self.lowStockThresholdCol.longValue(in: row).map { Int($0) },
            imageURLs: Self.imageURLsCol.textValue(in: row)?.decodeJSON(as: [String].self),
            designCode: Self.designCodeCol.textValue(in: row),
            variantsJSON: Self.variantsJSONCol.textValue(in: row),
            warrantyMonths: Self.warrantyMonthsCol.longValue(in: row).map { Int($0) }
        )
    }

    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.idCol] = SQLValue(id)
        row[Self.nameCol] = SQLValue(name)
        row[Self.currentStockCol] = SQLValue(currentStock)
        row[Self.billMachineNumberCol] = SQLValue(billMachineNumber)
        row[Self.lastSoldDateCol] = lastSoldDate.map { .real($0.timeIntervalSince1970) } ?? .null
        row[Self.isHotkeyCol] = SQLValue(isHotkey.stringValue)
        row[Self.updatedAtCol] = updatedAt.map { .real($0.timeIntervalSince1970) } ?? .null
        row[Self.isDeletedCol] = SQLValue(isDeleted.stringValue)
        row[Self.barcodeCol] = barcode.map { SQLValue($0) } ?? .null
        row[Self.sellPriceCol] = sellPrice.map { SQLValue($0) } ?? .null
        row[Self.costPriceCol] = costPrice.map { SQLValue($0) } ?? .null
        row[Self.wholesalePriceCol] = wholesalePrice.map { SQLValue($0) } ?? .null
        row[Self.categoryIdCol] = categoryId.map { SQLValue($0) } ?? .null
        row[Self.unitCol] = unit.map { SQLValue($0) } ?? .null
        row[Self.lowStockThresholdCol] = lowStockThreshold.map { SQLValue($0) } ?? .null
        row[Self.imageURLsCol] = imageURLs.map { SQLValue($0.string) } ?? .null
        row[Self.designCodeCol] = designCode.map { SQLValue($0) } ?? .null
        row[Self.variantsJSONCol] = variantsJSON.map { SQLValue($0) } ?? .null
        row[Self.warrantyMonthsCol] = warrantyMonths.map { SQLValue($0) } ?? .null
    }

    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let nameCol = SQLColumn(name: "name", type: .text)
    public static let currentStockCol = SQLColumn(name: "currentStock", type: .long)
    public static let billMachineNumberCol = SQLColumn(name: "billMachineNumber", type: .long)
    public static let lastSoldDateCol = SQLColumn(name: "lastSoldDate", type: .real)
    public static let isHotkeyCol = SQLColumn(name: "isHotkey", type: .text)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .text)
    public static let barcodeCol = SQLColumn(name: "barcode", type: .text)
    public static let sellPriceCol = SQLColumn(name: "sellPrice", type: .real)
    public static let costPriceCol = SQLColumn(name: "costPrice", type: .real)
    public static let wholesalePriceCol = SQLColumn(name: "wholesalePrice", type: .real)
    public static let categoryIdCol = SQLColumn(name: "categoryId", type: .text)
    public static let unitCol = SQLColumn(name: "unit", type: .text)
    public static let lowStockThresholdCol = SQLColumn(name: "lowStockThreshold", type: .long)
    public static let imageURLsCol = SQLColumn(name: "imageURLs", type: .text)
    public static let designCodeCol = SQLColumn(name: "designCode", type: .text)
    public static let variantsJSONCol = SQLColumn(name: "variantsJSON", type: .text)
    public static let warrantyMonthsCol = SQLColumn(name: "warrantyMonths", type: .long)
}
