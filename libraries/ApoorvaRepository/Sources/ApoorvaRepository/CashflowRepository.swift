//
//  File.swift
//  ApoorvaRepository
//
//  Created by Manikanta Nandam on 14/07/26.
//

import Foundation
import ApoorvaOfflineStorage
import ApoorvaServices
import ApoorvaModels

public final class CashflowRepository: @unchecked Sendable {
    private let localDB: AppDatabase
    private let remoteAPI: FirestoreSyncService
    
    // We pass the database in so it shares the same GRDB connection pool as Sales
    public init(database: AppDatabase) {
        self.localDB = database
        self.remoteAPI = FirestoreSyncService()
    }
    
    // MARK: - Data Reads
    public func getAllTransactions() async throws -> [CashflowTransaction] {
        return try await localDB.getAllCashflowTransactions()
    }
    
    public func getBalances() async throws -> (cash: Double, upi: Double, total: Double) {
        return try await localDB.getCurrentBalances()
    }
    
    // MARK: - Orchestration Logic (Firebase Pull)
    public func performCashflowSync(for orgId: String) async throws {
        print("🔄 Syncing Cashflow...")
        let lastSync = try await localDB.getLastSyncDate(for: "cashflow_\(orgId)")
        
        // Fetch deltas using the method we added to FirestoreSyncService earlier
        let modifiedTransactions = try await remoteAPI.fetchCashflowDeltas(for: orgId, since: lastSync)
        
        if !modifiedTransactions.isEmpty {
            try await localDB.upsertCashflowTransactions(modifiedTransactions)
            
            // Advance the sync cursor using the safest "max date" method we fixed earlier!
            if let latestDate = modifiedTransactions.map({ $0.updatedAt }).max() {
                try await localDB.updateSyncDate(latestDate, for: "cashflow_\(orgId)")
            }
        }
        print("✅ Cashflow Delta Sync Completed for \(orgId)!")
    }
    
    // MARK: - Data Writes (Local First + Cloud Push)
        public func addTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws {
            
            // 1. Save to local SQLite instantly so the UI updates without waiting for the network
            try await localDB.upsertCashflowTransactions([transaction])
            
            // 2. Push to Firestore so other devices (like the iPad) get the new transaction
            Task {
                do {
                    try await remoteAPI.pushCashflowTransaction(transaction, for: orgId)
                } catch {
                    // In a production app, you might flag this transaction in SQLite as 'needsSync = true'
                    // so it can retry later if the Wi-Fi is currently down!
                    print("⚠️ Failed to push transaction to cloud. It is safely stored locally. Error: \(error)")
                }
            }
        }
}
