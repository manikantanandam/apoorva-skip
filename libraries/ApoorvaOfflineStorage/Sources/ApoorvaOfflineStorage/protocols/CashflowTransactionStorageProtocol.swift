//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation
import ApoorvaModels

public protocol CashflowTransactionStorageProtocol: Sendable {
    
    func getCashflowTransactions() throws -> [CashflowTransaction]
    
    func saveCashflowTransactions(transactions: [CashflowTransaction]) throws

    func saveCashflowTransaction(transaction: CashflowTransaction) throws
        
    func getCashflowTransaction(id: String) throws -> CashflowTransaction?

    func updateCashflowTransaction(transaction: CashflowTransaction) throws
    
    func deleteCashflowTransaction(id: String) throws // Hard delete
    
    func markAsDeleted(id: String) throws  // Soft delete
}
