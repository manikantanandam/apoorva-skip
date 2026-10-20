//
//  File.swift
//  ApoorvaRepository
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaOfflineStorage
import ApoorvaModels
import ApoorvaServices

public protocol CashflowTransactionRepositoryProtocol: Sendable {
    func getCashflowTransactions() async throws -> [CashflowTransaction]
    func saveCashflowTransaction(transaction: CashflowTransaction) async throws
    func updateCashflowTransaction(_ transaction: CashflowTransaction) async throws
    func deleteCashflowTransaction(id: String) async throws // Hard delete
    func markAsDeleted(id: String) async throws  // Soft delete
    func sync(force: Bool) async throws
}


public final actor CashflowTransactionRepository: CashflowTransactionRepositoryProtocol {

    let storage: CashflowTransactionStorageProtocol
    let service: CashflowTransactionServiceProtocol
    let userRepository: UserRepositoryProtocol
    let syncStorage: SyncStorage
    
    public init(storage: CashflowTransactionStorageProtocol,
                service: CashflowTransactionServiceProtocol,
                userRepository: UserRepositoryProtocol,
                syncStorage: SyncStorage) {
        self.storage = storage
        self.service = service
        self.userRepository = userRepository
        self.syncStorage = syncStorage
    }
    
    public func getCashflowTransactions() async throws -> [CashflowTransaction] {
        let transactions = try await storage.getCashflowTransactions()
        return transactions
    }
    
    public func saveCashflowTransaction(transaction: CashflowTransaction) async throws {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }
        try await service.addCashflowTransaction(transaction, for: orgId)
        try await sync(force: false)
    }
    
    public func updateCashflowTransaction(_ transaction: CashflowTransaction) async throws {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }
        try await service.updateCashflowTransaction(transaction, for: orgId)
        try await sync(force: false)
    }
    
    public func deleteCashflowTransaction(id: String) async throws {
        try await storage.deleteCashflowTransaction(id: id)
    }
    
    public func markAsDeleted(id: String) async throws {
        try await storage.markAsDeleted(id: id)
    }
    
    public func sync(force: Bool) async throws {
        print("Started sync")
        let user = try await userRepository.getCurrentUser()
        print("Received used")

        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }
        
        let transactions: [CashflowTransaction]
        
        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: CashflowTransaction.table.name)
        print("Last updted date \(lastUpdatedDate)")
        
        if let lastUpdatedDate, !force {
            transactions = try await service.getCashflowTransactions(since: Date(timeIntervalSince1970: lastUpdatedDate), for: orgId)
        } else {
            transactions = try await service.getCashflowTransactions(for: orgId)
        }
        try await storage.saveCashflowTransactions(transactions: transactions)
        guard
            let transactionWithMinUpdatedAt = transactions.transactionWithMaxDate
        else { return }
        
        print("transaction with min update \(transactionWithMinUpdatedAt)")
        print("saving lastUpdatedDate \(transactionWithMinUpdatedAt.updatedAt)")

        try await syncStorage.updateSyncTimestamp(
            for: CashflowTransaction.table.name,
            timestamp: transactionWithMinUpdatedAt.updatedAt.timeIntervalSince1970
        )
    }
}


private extension Array where Element == CashflowTransaction {
    var transactionWithMaxDate: CashflowTransaction? {
        self.max(by: {
            return $0.updatedAt < $1.updatedAt
        })
    }
}
