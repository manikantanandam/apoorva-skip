//
//  OrganizationService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
import ManiLogger
@preconcurrency import FirebaseFirestore

private let logger = AppLogger(category: .network)

public protocol OrganizationServiceProtocol: Sendable {
    func getOrganization(for orgId: String) async throws -> Organization
    func getOrganizations(since lastSync: Date, assignedIds: [String]) async throws -> [Organization]
}

public final class OrganizationService: OrganizationServiceProtocol {

    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func getOrganization(for orgId: String) async throws -> Organization {
        guard let document = try await store.getDocument(path: "\(String.organizations)/\(orgId)") else {
            throw NSError(domain: "OrganizationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Organization not found."])
        }
        return try Firestore.Decoder().decode(Organization.self, from: document.data)
    }

    public func getOrganizations(since lastSync: Date, assignedIds: [String]) async throws -> [Organization] {
        guard !assignedIds.isEmpty else { return [] }

        // Queries a regular field instead of the Document ID
        let query = StoreQuery(conditions: [
            .isIn(field: "id", values: assignedIds),
            .greaterThan(field: "updatedAt", date: lastSync)
        ])
        let records = try await store.fetch(Organization.self, collection: .organizations, query: query)
        logger.info("Fetched \(records.count) Organizations")
        return records
    }
}
