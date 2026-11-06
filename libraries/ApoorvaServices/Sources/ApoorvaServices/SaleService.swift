//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels
@preconcurrency import FirebaseFirestore

public protocol SaleServiceProtocol: Sendable {
    
    func getSales(for orgId: String) async throws -> [Sale]
    func getSales(since lastSync: Date, for orgId: String) async throws -> [Sale]
}


public final class SaleService: SaleServiceProtocol {

    private let db = Firestore.firestore()
    
    public init() {}

    public func getSales(for orgId: String) async throws -> [Sale] {
        try await sales(for: orgId)
    }
    
    public func getSales(since lastSync: Date, for orgId: String) async throws -> [Sale] {
        try await sales(since: lastSync, for: orgId)
    }
}

private extension SaleService {
    func sales(since lastSync: Date? = nil, for orgId: String) async throws -> [Sale] {
        let baseCollection = db
                .collection(.organizations)
                .document(orgId)
                .collection(.sales)
                
        var query: Query = baseCollection
            
        if let lastSync = lastSync {
            print("Fetching Sales in sale service \(lastSync)")
                let timestamp = Timestamp(date: lastSync)
                
            query = baseCollection.whereField("timestamp", isGreaterThan: timestamp)
            }
            print("🌐 Fetching Sales for Org: \(orgId)...")
            let snapshot = try await query.getDocuments()
            
            var successfulRecords: [Sale] = []
            for document in snapshot.documents {
                do {
                    let record = try document.data(as: Sale.self)
                    successfulRecords.append(record)
                } catch { print("❌ Failed to decode Sale: \(document.documentID) - \(error)") }
            }
            
            print("✅ Fetched \(successfulRecords.count) Sales.")
            return successfulRecords
        }
}
