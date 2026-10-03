//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 14/07/26.
//

import Foundation

import Foundation
import GRDB
import ApoorvaModels

// 1. Conform the Enums to GRDB's value convertible protocol
extension CashflowTransaction.TransactionType: @retroactive DatabaseValueConvertible {}
extension CashflowTransaction.PaymentMode: @retroactive DatabaseValueConvertible {}

// 2. Conform the Model to GRDB's record protocols
extension CashflowTransaction: @retroactive FetchableRecord, @retroactive PersistableRecord {
    
    // Optional: Explicitly define the table name if you ever want it
    // to differ from the exact struct name.
    public static let databaseTableName = "CashflowTransaction"
    
}
