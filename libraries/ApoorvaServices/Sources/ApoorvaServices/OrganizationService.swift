//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels
@preconcurrency import FirebaseFirestore

public protocol OrganizationServiceProtocol: Sendable {
    func getOrganization(for orgId: String) async throws -> Organization
    func getOrganizations(since lastSync: Date, assignedIds: [String]) async throws -> [Organization]
}

public final class OrganizationService: OrganizationServiceProtocol {
    
    private let db = Firestore.firestore()
    
    public init() {}
    
    public func getOrganization(for orgId: String) async throws -> Organization {
        let docRef = db.collection(.organizations).document(orgId)
        let snapshot = try await docRef.getDocument()
        guard snapshot.exists else {
            throw NSError(domain: "OrganizationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization not found."])
        }
        return try snapshot.data(as: Organization.self)
    }
    
    public func getOrganizations(since lastSync: Date, assignedIds: [String]) async throws -> [Organization] {
        guard !assignedIds.isEmpty else { return [] }
        
        let baseCollection = db.collection(.organizations)
        let query = baseCollection
                    .whereField("id", in: assignedIds) // Querying a regular field instead of the Document ID
                    .whereField("updatedAt", isGreaterThan: Timestamp(date: lastSync))
            
        let snapshot = try await query.getDocuments()
        
        var updatedRecords: [Organization] = []
        for document in snapshot.documents {
            do {
                let org = try document.data(as: Organization.self)
                updatedRecords.append(org)
            } catch {
                print("❌ Failed to decode Organization: \(document.documentID) - \(error)")
            }
        }
        print("Fetched orgs from firestore \(updatedRecords.count)")
        return updatedRecords
    }
}
