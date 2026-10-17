//
//  Sale+SkipSQL.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import ApoorvaModels
import SkipSQL

extension Sale: @retroactive SQLCodable {
    
    public static var table: SQLTable {
        SQLTable(
            name: "Sale",
            columns: [
                idCol,
                staffIdCol,
                customerPhoneCol,
                customerNameCol,
                itemsCol,
                subtotalCol,
                overallDiscountPercentCol,
                overallDiscountAmountCol,
                roundOffCol,
                netPayableCol,
                paymentsCol,
                timestampCol,
                sourceCol,
                statusCol,
                whatsappStatusCol,
                updatedAtCol,
                isDeletedCol
            ]
        )
    }
    
    public init(row: SQLRow, context: SQLContext) throws {
        let id = try Self.idCol.textValueRequired(in: row)
        let staffId = try Self.staffIdCol.textValueRequired(in: row)
        let customerPhone = try Self.customerPhoneCol.textValueRequired(in: row)
        let customerName = try Self.customerNameCol.textValueRequired(in: row)
        let items = try Self.itemsCol.textValueRequired(in: row)
        let subtotal = try Self.subtotalCol.realValueRequired(in: row)
        let overallDiscountPercent = try Self.overallDiscountPercentCol.realValueRequired(in: row)
        let overallDiscountAmount = try Self.overallDiscountAmountCol.realValueRequired(in: row)
        let roundOff = try Self.roundOffCol.realValueRequired(in: row)
        let netPayable = try Self.netPayableCol.realValueRequired(in: row)
        let payments = try Self.paymentsCol.textValueRequired(in: row)
        let timestamp = try Self.timestampCol.realValueRequired(in: row)
        let source = try Self.sourceCol.textValueRequired(in: row)
        let status = try Self.statusCol.textValueRequired(in: row)
        let whatsappStatus = try Self.whatsappStatusCol.textValueRequired(in: row)
        let updatedAt = Self.updatedAtCol.realValue(in: row)
        let isDeleted = try Self.isDeletedCol.longValueRequired(in: row)
        
        self.init(id: id,
                  staffId: staffId,
                  customerPhone: customerPhone,
                  customerName: customerName,
                  items: items.decodeJSON(as: [SaleItem].self) ?? [],
                  subtotal: subtotal,
                  overallDiscountPercent: overallDiscountPercent,
                  overallDiscountAmount: overallDiscountAmount,
                  roundOff: roundOff,
                  netPayable: netPayable,
                  payments: payments.decodeJSON(as: [PaymentMode: Double].self) ?? [:],
                  timestamp: timestamp.date,
                  source: source,
                  status: status,
                  whatsappStatus: whatsappStatus,
                  updatedAt: updatedAt?.date,
                  isDeleted: isDeleted.boolValue)
    }
    
    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.idCol] = SQLValue(self.id)
        row[Self.staffIdCol] = SQLValue(self.staffId)
        row[Self.customerNameCol] = SQLValue(self.customerName)
        row[Self.customerPhoneCol] = SQLValue(self.customerPhone)
        row[Self.itemsCol] = SQLValue(self.items.string)
        row[Self.subtotalCol] = SQLValue(self.subtotal)
        row[Self.overallDiscountPercentCol] = SQLValue(self.overallDiscountPercent)
        row[Self.overallDiscountAmountCol] = SQLValue(self.overallDiscountAmount)
        
        row[Self.roundOffCol] = SQLValue(self.roundOff)
        row[Self.netPayableCol] = SQLValue(self.netPayable)
        row[Self.paymentsCol] = SQLValue(self.payments.string)
        row[Self.timestampCol] = SQLValue(self.timestamp.timeIntervalSince1970)
        row[Self.sourceCol] = SQLValue(self.source)
        row[Self.statusCol] = SQLValue(self.status)
        row[Self.whatsappStatusCol] = SQLValue(self.overallDiscountAmount)
        if let date = self.updatedAt {
            row[Self.updatedAtCol] = .real(date.timeIntervalSince1970)
        } else {
            row[Self.updatedAtCol] = .null
        }
        row[Self.isDeletedCol] = SQLValue(self.isDeleted.intValue)
        

    }
    
    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let staffIdCol = SQLColumn(name: "staffId", type: .text)
    public static let customerPhoneCol = SQLColumn(name: "customerPhone", type: .text)
    public static let customerNameCol = SQLColumn(name: "customerName", type: .text)
    public static let itemsCol = SQLColumn(name: "items", type: .text) // Serializes JSON arrays automatically
    public static let subtotalCol = SQLColumn(name: "subtotal", type: .real)
    public static let overallDiscountPercentCol = SQLColumn(name: "overallDiscountPercent", type: .real)
    public static let overallDiscountAmountCol = SQLColumn(name: "overallDiscountAmount", type: .real)
    public static let roundOffCol = SQLColumn(name: "roundOff", type: .real)
    public static let netPayableCol = SQLColumn(name: "netPayable", type: .real)
    public static let paymentsCol = SQLColumn(name: "payments", type: .text) // Serializes JSON dictionaries automatically
    public static let timestampCol = SQLColumn(name: "timestamp", type: .real)
    public static let sourceCol = SQLColumn(name: "source", type: .text)
    public static let statusCol = SQLColumn(name: "status", type: .text)
    public static let whatsappStatusCol = SQLColumn(name: "whatsappStatus", type: .text)
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .long)
}
