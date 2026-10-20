//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation
import ApoorvaModels

public protocol CashflowTransactionStorageProtocol: Sendable {
    
    func getCashflowTransactions() async throws -> [CashflowTransaction]
    
    func saveCashflowTransactions(transactions: [CashflowTransaction]) async throws

    func saveCashflowTransaction(transaction: CashflowTransaction) async throws
        
    func getCashflowTransaction(id: String) async throws -> CashflowTransaction?

    func updateCashflowTransaction(transaction: CashflowTransaction) async throws
    
    func deleteCashflowTransaction(id: String) async throws // Hard delete
    
    func markAsDeleted(id: String) async throws  // Soft delete
}
