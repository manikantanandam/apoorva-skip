//
//  DailyCashflowSummaryService.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels
@preconcurrency import FirebaseFirestore

public protocol DailyCashflowSummaryServiceProtocol: Sendable {
    func getDailyCashflowSummaries(for orgId: String) async throws -> [DailyCashflowSummary]
    func getDailyCashflowSummaries(since lastSync: Date, for orgId: String) async throws -> [DailyCashflowSummary]
    func getDailyCashflowSummary(orgId: String, date: String) async throws -> DailyCashflowSummary
    func addDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws
    func updateDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws
}

public final class DailyCashflowSummaryService: DailyCashflowSummaryServiceProtocol {
    
    private let db = Firestore.firestore()
    
    // Using a string extension pattern similar to .cashflow[cite: 14] and .organizations[cite: 13]
    private let collectionName = "dailyCashflowSummaries"
    
    public init() {}
    
    public func getDailyCashflowSummaries(for orgId: String) async throws -> [DailyCashflowSummary] {
        try await dailyCashflowTransactions(for: orgId)
    }
    
    public func getDailyCashflowSummary(orgId: String, date: String) async throws -> DailyCashflowSummary {
        print("🌐 Fetching Daily Cashflow Transactions for Org: \(orgId) for date \(date) ...")
        let query = db
            .collection(.organizations)
            .document(orgId)
            .collection(collectionName)
            .document(date)
        
        let snapshot = try await query.getDocument()
        do {
            let record = try snapshot.data(as: DailyCashflowSummary.self)
            return record
        } catch {
            print("❌ Failed to decode DailyCashflowSummary: \(snapshot.documentID) - \(error)")
            throw error
        }
    }
    
    public func getDailyCashflowSummaries(since lastSync: Date, for orgId: String) async throws -> [DailyCashflowSummary] {
        do {
            return try await dailyCashflowTransactions(since: lastSync, for: orgId)
        } catch {
            print("Eror in fething firestore \(error.localizedDescription)")
            throw error
        }
        
    }

    
    public func addDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws {
        let docRef = db
            .collection("organizations")
            .document(orgId)
            .collection(collectionName)
            .document(summary.id)
        
        // Prevent duplicates by checking if the document already exists[cite: 14]
        let snapshot = try await docRef.getDocument()
        guard !snapshot.exists else {
            print("⚠️ Daily Cashflow Summary \(summary.id) already exists. Skipping insertion.")
            return
        }
        
        try docRef.setData(from: summary)
    }
    
    public func updateDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws {
        let docRef = db
            .collection("organizations")
            .document(orgId)
            .collection(collectionName)
            .document(summary.id)
        
        // Note: The DailyCashflowSummary model currently lacks an `updatedAt` field[cite: 6, 15],
        // so we write the data directly without injecting a new timestamp like we do for CashflowTransaction[cite: 14].
        try docRef.setData(from: summary, merge: true)
    }
}


private extension DailyCashflowSummaryService {
    func dailyCashflowTransactions(since lastSync: Date? = nil, for orgId: String) async throws -> [DailyCashflowSummary] {
        let baseCollection = db
            .collection(.organizations)
            .document(orgId)
            .collection(collectionName)
        
        var query: Query = baseCollection
        
        if let lastSync = lastSync {
            let timestamp = Timestamp(date: lastSync)
            
            query = baseCollection.whereField("updatedAt", isGreaterThan: timestamp)
            print("🌐 Fetching Daily Cashflow Transactions for Org: \(orgId)... for last sync \(lastSync)")

        }
//        query = query.limit(to: 10)
        print("🌐 Fetching Daily Cashflow Transactions for Org: \(orgId)...")
        let snapshot = try await query.getDocuments()
        
        var summaries: [DailyCashflowSummary] = []
        for document in snapshot.documents {
            do {
                let record = try document.data(as: DailyCashflowSummary.self)
                summaries.append(record)
            } catch { print("❌ Failed to decode DailyCashflowSummary: \(document.documentID) - \(error)") }
        }
        
        print("✅ Fetched \(summaries.count) Daily Cashflow Transactions.")
        return summaries
    }
}
