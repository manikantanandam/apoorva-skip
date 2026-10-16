//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels
@preconcurrency import FirebaseFirestore

public protocol CashflowTransactionServiceProtocol: Sendable {
    
    func getCashflowTransactions(for orgId: String) async throws -> [CashflowTransaction]
    func getCashflowTransactions(since lastSync: Date, for orgId: String) async throws -> [CashflowTransaction]
}


public final class CashflowTransactionService: CashflowTransactionServiceProtocol {
    
    private let db = Firestore.firestore()
    
    public init() {}
    
    public func getCashflowTransactions(for orgId: String) async throws -> [CashflowTransaction] {
        try await cashflowTransactions(for: orgId)
    }
    
    public func getCashflowTransactions(since lastSync: Date, for orgId: String) async throws -> [CashflowTransaction] {
        try await cashflowTransactions(since: lastSync, for: orgId)
    }
    
    public func addCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws {
        let docRef = db
            .collection(.organizations)
            .document(orgId)
            .collection(.cashflow)
            .document(transaction.id)
        
        // Prevent duplicates by checking if the document already exists
        let snapshot = try await docRef.getDocument()
        guard !snapshot.exists else {
            print("⚠️ Cashflow Transaction \(transaction.id) already exists. Skipping insertion.")
            return
        }
        
        try docRef.setData(from: transaction)
    }
    
    public func updateCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws {
        var updatedTransaction = transaction
        updatedTransaction.updatedAt = Date() // Ensure timestamp updates on modification[cite: 14]
        
        let docRef = db
            .collection(.organizations)
            .document(orgId)
            .collection(.cashflow)
            .document(transaction.id)
        
        try docRef.setData(from: updatedTransaction, merge: true)
    }
    
    public func deleteCashflowTransaction(id: String, for orgId: String) async throws {
        let docRef = db
            .collection(.organizations)
            .document(orgId)
            .collection(.cashflow)
            .document(id)
        
        // Soft-delete to keep offline sync working via the isDeleted flag[cite: 14]
        try await docRef.updateData([
            "isDeleted": true,
            "updatedAt": Timestamp(date: Date())
        ])
    }
}

private extension CashflowTransactionService {
    func cashflowTransactions(since lastSync: Date? = nil, for orgId: String) async throws -> [CashflowTransaction] {
        let baseCollection = db
            .collection(.organizations)
//            .document(orgId)
            .document("YOUR_ORG_ID")
            .collection(.cashflow)
        
        var query: Query = baseCollection
        
        if let lastSync = lastSync {
            let timestamp = Timestamp(date: lastSync)
            
            query = baseCollection.whereFilter(
                Filter.orFilter([
                    Filter.whereField("updatedAt", isGreaterThan: timestamp),
                    Filter.whereField("timestamp", isGreaterThan: timestamp)
                ])
            )
        }
        
        print("🌐 Fetching Cashflow Transactions for Org: \(orgId)...")
        let snapshot = try await query.getDocuments()
        
        var successfulRecords: [CashflowTransaction] = []
        for document in snapshot.documents {
            do {
                let record = try document.data(as: CashflowTransaction.self)
                successfulRecords.append(record)
            } catch { print("❌ Failed to decode Category: \(document.documentID) - \(error)") }
        }
        
        print("✅ Fetched \(successfulRecords.count) Cashflow Transactions.")
        return successfulRecords
    }
}
