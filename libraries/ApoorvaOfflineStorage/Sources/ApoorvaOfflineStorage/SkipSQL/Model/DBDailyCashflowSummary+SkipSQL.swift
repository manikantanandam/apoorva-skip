//
//  DailyCashflowSummary+SkipSQL.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

extension DailyCashflowSummary: @retroactive SQLCodable {
    
    public static var table: SkipSQLCore.SQLTable {
        SQLTable(
            name: "DailyCashflowSummary",
            columns: [
                idCol,
                dateCol,
                closingBalancesCol,
                openingBalancesCol
            ]
        )
    }
    
    public init(row: SkipSQLCore.SQLRow, context: SkipSQLCore.SQLContext) throws {
        // The id is dynamically computed from the date in the model[cite: 6], so it is skipped during initialization.
        let dateVal = try Self.dateCol.realValueRequired(in: row)
        let openingBalancesRaw = try Self.openingBalancesCol.textValueRequired(in: row)
        let closingBalancesRaw = try Self.closingBalancesCol.textValueRequired(in: row)
        let updatedAt = Self.updatedAtCol.realValue(in: row) ?? 0
        
        let openingBalanceValue = openingBalancesRaw.decodeJSON(as: [AccountBalance].self) ?? []
        let closingBalanceValue = closingBalancesRaw.decodeJSON(as: [AccountBalance].self) ?? []

        self.init(
            date: dateVal.date,
            openingBalances: openingBalanceValue,
            closingBalances: closingBalanceValue,
            updatedAt: updatedAt
        )
    }
    
    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.idCol] = SQLValue(self.id)
        row[Self.dateCol] = SQLValue(self.date.timeIntervalSince1970)
        row[Self.openingBalancesCol] = SQLValue(self.openingBalances.string)
        row[Self.closingBalancesCol] = SQLValue(self.closingBalances.string)
    }
    
    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let dateCol = SQLColumn(name: "date", type: .real)
    public static let openingBalancesCol = SQLColumn(name: "openingBalances", type: .text)
    public static let closingBalancesCol = SQLColumn(name: "closingBalances", type: .text)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
}
