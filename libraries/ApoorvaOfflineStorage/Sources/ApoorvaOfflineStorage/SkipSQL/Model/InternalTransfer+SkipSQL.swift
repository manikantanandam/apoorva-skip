//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

extension InternalTransfer: @retroactive SQLCodable {
    
    public static var table: SQLTable {
        SQLTable(
            name: "InternalTransfer",
            columns: [
                idCol,
                fromAccountIdCol,
                toAccountIdCol,
                amountCol,
                transferTypeCol,
                timestampCol,
                updatedAtCol,
                isDeletedCol
            ]
        )
    }
    
    public init(row: SQLRow, context: SQLContext) throws {
        let id = try Self.idCol.textValueRequired(in: row)
        let fromAccountId = try Self.fromAccountIdCol.textValueRequired(in: row)
        let toAccountId = try Self.toAccountIdCol.textValueRequired(in: row)
        let amount = try Self.amountCol.realValueRequired(in: row)
        let transferType = try Self.transferTypeCol.textValueRequired(in: row)
        let timestamp = try Self.timestampCol.realValueRequired(in: row)
        let updatedAt = try Self.updatedAtCol.realValueRequired(in: row)
        let isDeleted = try Self.isDeletedCol.longValueRequired(in: row)
        
        self.init(id: id,
                  fromAccountId: fromAccountId,
                  toAccountId: toAccountId,
                  amount: amount,
                  transferType: transferType,
                  timestamp: Date(timeIntervalSince1970: timestamp),
                  updatedAt: Date(timeIntervalSince1970: updatedAt),
                  isDeleted: isDeleted.boolValue)
    }
    
    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.idCol] = SQLValue(self.id)
        row[Self.fromAccountIdCol] = SQLValue(self.fromAccountId)
        row[Self.toAccountIdCol] = SQLValue(self.toAccountId)
        row[Self.amountCol] = SQLValue(self.amount)
        row[Self.transferTypeCol] = SQLValue(self.transferType)
        
        row[Self.timestampCol] = SQLValue(self.timestamp.timeIntervalSince1970)
        row[Self.updatedAtCol] = SQLValue(self.updatedAt.timeIntervalSince1970)
        
        row[Self.isDeletedCol] = SQLValue(self.isDeleted.int64Value)
    }
    
    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let fromAccountIdCol = SQLColumn(name: "fromAccountId", type: .text)
    public static let toAccountIdCol = SQLColumn(name: "toAccountId", type: .text)
    public static let amountCol = SQLColumn(name: "amount", type: .real)
    public static let transferTypeCol = SQLColumn(name: "transferType", type: .text)
    public static let timestampCol = SQLColumn(name: "timestamp", type: .real)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .long)
}
