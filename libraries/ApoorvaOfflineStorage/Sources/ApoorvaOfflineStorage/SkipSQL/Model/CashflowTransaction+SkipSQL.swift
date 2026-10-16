//
//  CashflowTransaction+SkipSQL.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

extension CashflowTransaction: @retroactive SQLCodable {
    
    public static var table: SQLTable {
        SQLTable(
            name: "CashflowTransaction",
            columns: [
                idCol,
                timestampCol,
                particularsCol,
                amountCol,
                transactionTypeCol,
                paymentModeCol,
                categoryCol,
                subCategoryCol,
                personCol,
                isDeletedCol,
                updatedAtCol
            ]
        )
    }
    
    public init(row: SQLRow, context: SQLContext) throws {
        let id = try Self.idCol.textValueRequired(in: row)
        let timestamp = try Self.timestampCol.realValueRequired(in: row)
        let particulars = try Self.particularsCol.textValueRequired(in: row)
        let amount = try Self.amountCol.realValueRequired(in: row)
        
        let transactionTypeRaw = try Self.transactionTypeCol.textValueRequired(in: row)
        let paymentModeRaw = try Self.paymentModeCol.textValueRequired(in: row)
        
        let category = try Self.categoryCol.textValueRequired(in: row)
        let subCategory = Self.subCategoryCol.textValue(in: row) // Optional
        let person = Self.personCol.textValue(in: row) // Optional
        
        let isDeleted = try Self.isDeletedCol.longValueRequired(in: row)
        let updatedAt = try Self.updatedAtCol.realValueRequired(in: row)
        
        self.init(id: id,
                  timestamp: Date(timeIntervalSince1970: timestamp),
                  particulars: particulars,
                  amount: amount,
                  transactionType: TransactionType(rawValue: transactionTypeRaw) ?? .unknown,
                  paymentMode: PaymentMode(rawValue: paymentModeRaw) ?? .unknown,
                  category: category,
                  subCategory: subCategory,
                  person: person,
                  isDeleted: isDeleted.boolValue,
                  updatedAt: updatedAt.date)
    }
    
    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.idCol] = SQLValue(self.id)
        row[Self.timestampCol] = SQLValue(self.timestamp.timeIntervalSince1970)
        row[Self.particularsCol] = SQLValue(self.particulars)
        row[Self.amountCol] = SQLValue(self.amount)
        
        row[Self.transactionTypeCol] = SQLValue(self.transactionType.rawValue)
        row[Self.paymentModeCol] = SQLValue(self.paymentMode.rawValue)
        
        row[Self.categoryCol] = SQLValue(self.category)
        
        // Optional Bindings
        if let subCat = self.subCategory {
            row[Self.subCategoryCol] = .text(subCat)
        } else {
            row[Self.subCategoryCol] = .null
        }
        
        if let p = self.person {
            row[Self.personCol] = .text(p)
        } else {
            row[Self.personCol] = .null
        }
        
        row[Self.isDeletedCol] = SQLValue(self.isDeleted.int64Value)
        row[Self.updatedAtCol] = SQLValue(self.updatedAt.timeIntervalSince1970)
    }
    
    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let timestampCol = SQLColumn(name: "timestamp", type: .real)
    public static let particularsCol = SQLColumn(name: "particulars", type: .text)
    public static let amountCol = SQLColumn(name: "amount", type: .real)
    public static let transactionTypeCol = SQLColumn(name: "transactionType", type: .text)
    public static let paymentModeCol = SQLColumn(name: "paymentMode", type: .text)
    public static let categoryCol = SQLColumn(name: "category", type: .text)
    public static let subCategoryCol = SQLColumn(name: "subCategory", type: .text)
    public static let personCol = SQLColumn(name: "person", type: .text)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .long)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
}
