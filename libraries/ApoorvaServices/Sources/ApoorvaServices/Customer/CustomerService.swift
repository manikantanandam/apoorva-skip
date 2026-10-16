//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels
@preconcurrency import FirebaseFirestore

public protocol CustomerServiceProtocol: Sendable {
    
    func getCustomers(for orgId: String) async throws -> [Customer]
    func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer]
}


public final class CustomerService: CustomerServiceProtocol {

    private let db = Firestore.firestore()
    
    public init() {}

    public func getCustomers(for orgId: String) async throws -> [Customer] {
        try await customers(for: orgId)
    }
    
    public func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer] {
        try await customers(since: lastSync, for: orgId)
    }
}

private extension CustomerService {
    func customers(since lastSync: Date? = nil, for orgId: String) async throws -> [Customer] {
        let baseCollection = db
                .collection(.organizations)
                .document(orgId)
                .collection(.customers)
                
        var query: Query = baseCollection
            
        if let lastSync = lastSync {
                let timestamp = Timestamp(date: lastSync)
                
                query = baseCollection.whereFilter(
                    Filter.orFilter([
                        Filter.whereField("updatedAt", isGreaterThan: timestamp),
                        Filter.whereField("lastPurchaseDate", isGreaterThan: timestamp)
                    ])
                )
            }
            
            print("🌐 Fetching Categories for Org: \(orgId)...")
            let snapshot = try await query.getDocuments()
            
            var successfulRecords: [Customer] = []
            for document in snapshot.documents {
                do {
                    var record = try document.data(as: Customer.self)
                    successfulRecords.append(record)
                } catch { print("❌ Failed to decode Category: \(document.documentID) - \(error)") }
            }
            
            print("✅ Fetched \(successfulRecords.count) Categories.")
            return successfulRecords
        }
}
