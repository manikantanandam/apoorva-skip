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
    func addDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws
    func updateDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws
}

public final class DailyCashflowSummaryService: DailyCashflowSummaryServiceProtocol {
    
    private let db = Firestore.firestore()
    
    // Using a string extension pattern similar to .cashflow[cite: 14] and .organizations[cite: 13]
    private let collectionName = "dailyCashflowSummaries"
    
    public init() {}
    
    public func getDailyCashflowSummaries(for orgId: String) async throws -> [DailyCashflowSummary] {
        let baseCollection = db
            .collection("organizations")
            .document(orgId)
            .collection(collectionName)
        
        print("🌐 Fetching Daily Cashflow Summaries for Org: \(orgId)...")
        let snapshot = try await baseCollection.getDocuments()
        
        var successfulRecords: [DailyCashflowSummary] = []
        for document in snapshot.documents {
            do {
                let record = try document.data(as: DailyCashflowSummary.self)
                successfulRecords.append(record)
            } catch {
                print("❌ Failed to decode DailyCashflowSummary: \(document.documentID) - \(error)")
            }
        }
        
        print("✅ Fetched \(successfulRecords.count) Daily Cashflow Summaries.")
        return successfulRecords
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
