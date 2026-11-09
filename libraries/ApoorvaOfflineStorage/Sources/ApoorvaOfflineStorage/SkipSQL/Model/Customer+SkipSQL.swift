//
//  Customer+SkipSQL.swift
//  ApoorvaOfflineStorage
//

import ApoorvaModels
import ApoorvaUtilities
import SkipSQL

extension Customer: @retroactive SQLCodable {

    public static var table: SQLTable {
        SQLTable(name: "Customer", columns: baseColumns + addedColumns)
    }

    static let baseColumns: [SQLColumn] = [
        phoneCol, nameCol, createdAtCol, lastPurchaseDateCol, totalSalesCol, totalAmountSpentCol, updatedAtCol, isDeletedCol
    ]

    /// Columns added after v1 — created by `SchemaMigrations`, never by the initial table DDL on old installs.
    static let addedColumns: [SQLColumn] = [
        creditLimitCol, birthdayCol, dueBalanceCol, priceTierCol, notesCol, whatsappReceiptsCol
    ]

    public init(row: SQLRow, context: SQLContext) throws {
        self.init(name: Self.nameCol.textValue(in: row) ?? "",
                  phone: try Self.phoneCol.textValueRequired(in: row),
                  createdAt: Self.createdAtCol.realValue(in: row) ?? 0,
                  lastPurchaseDate: Self.lastPurchaseDateCol.realValue(in: row),
                  totalSales: Int(Self.totalSalesCol.longValue(in: row) ?? 0),
                  totalAmountSpent: Self.totalAmountSpentCol.realValue(in: row) ?? 0,
                  updatedAt: Self.updatedAtCol.realValue(in: row),
                  isDeleted: (Self.isDeletedCol.longValue(in: row) ?? 0).boolValue,
                  creditLimit: Self.creditLimitCol.realValue(in: row),
                  birthday: Self.birthdayCol.realValue(in: row),
                  dueBalance: Self.dueBalanceCol.realValue(in: row) ?? 0,
                  priceTier: Self.priceTierCol.textValue(in: row),
                  notes: Self.notesCol.textValue(in: row),
                  whatsappReceipts: (Self.whatsappReceiptsCol.longValue(in: row) ?? 1).boolValue)
    }

    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.phoneCol] = SQLValue(phone)
        row[Self.nameCol] = SQLValue(name)
        row[Self.createdAtCol] = SQLValue(createdAt)
        row[Self.lastPurchaseDateCol] = lastPurchaseDate.map { SQLValue($0) } ?? .null
        row[Self.totalSalesCol] = SQLValue(totalSales)
        row[Self.totalAmountSpentCol] = SQLValue(totalAmountSpent)
        row[Self.updatedAtCol] = updatedAt.map { SQLValue($0) } ?? .null
        row[Self.isDeletedCol] = SQLValue(isDeleted.intValue)
        row[Self.creditLimitCol] = creditLimit.map { SQLValue($0) } ?? .null
        row[Self.birthdayCol] = birthday.map { SQLValue($0) } ?? .null
        row[Self.dueBalanceCol] = SQLValue(dueBalance)
        row[Self.priceTierCol] = priceTier.map { SQLValue($0) } ?? .null
        row[Self.notesCol] = notes.map { SQLValue($0) } ?? .null
        row[Self.whatsappReceiptsCol] = SQLValue(whatsappReceipts.intValue)
    }

    public static let phoneCol = SQLColumn(name: "phone", type: .text, primaryKey: true)
    public static let nameCol = SQLColumn(name: "name", type: .text)
    public static let createdAtCol = SQLColumn(name: "createdAt", type: .real)
    public static let lastPurchaseDateCol = SQLColumn(name: "lastPurchaseDate", type: .real)
    public static let totalSalesCol = SQLColumn(name: "totalSales", type: .long)
    public static let totalAmountSpentCol = SQLColumn(name: "totalAmountSpent", type: .real)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .long)
    public static let creditLimitCol = SQLColumn(name: "creditLimit", type: .real)
    public static let birthdayCol = SQLColumn(name: "birthday", type: .real)
    public static let dueBalanceCol = SQLColumn(name: "dueBalance", type: .real)
    public static let priceTierCol = SQLColumn(name: "priceTier", type: .text)
    public static let notesCol = SQLColumn(name: "notes", type: .text)
    public static let whatsappReceiptsCol = SQLColumn(name: "whatsappReceipts", type: .long)
}
