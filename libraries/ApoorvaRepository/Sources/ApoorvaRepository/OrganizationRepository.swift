//
//  File.swift
//  ApoorvaRepository
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaOfflineStorage
import ApoorvaModels
import ApoorvaServices

public protocol OrganizationRepositoryProtocol: Sendable {
    func getOrganizations() async throws -> [Organization]
    func getOrganization(orgId: String) async throws -> Organization?
    func saveOrganization(organization: Organization) async throws
    func sync(force: Bool) async throws
}

public final actor OrganizationRepository: OrganizationRepositoryProtocol {
    
    let storage: OrganizationStorageProtocol
    let service: OrganizationServiceProtocol
    let userRepository: UserRepositoryProtocol
    let syncStorage: SyncStorage
    
    public init(
        storage: OrganizationStorageProtocol,
        service: OrganizationServiceProtocol,
        userRepository: UserRepositoryProtocol,
        syncStorage: SyncStorage
    ) {
        self.storage = storage
        self.service = service
        self.userRepository = userRepository
        self.syncStorage = syncStorage
    }
    
    public func getOrganizations() async throws -> [Organization] {
        let organizations = try await storage.getOrganizations()
        if organizations.isEmpty {
            try await sync(force: false)
            
            return try await storage.getOrganizations()
        }
        
        return organizations
    }
    
    public func getOrganization(orgId: String) async throws -> Organization? {
        try await sync(force: false)
        let organizations = try await storage.getOrganizations()
        return organizations.first(where: { $0.id == orgId })
    }
    
    public func saveOrganization(organization: Organization) async throws {
        try await storage.saveOrganization(organization: organization)
    }
    
    public func sync(force: Bool) async throws {
        print("Started Organization sync")
        
        let user = try await userRepository.getCurrentUser()
        
        // 1. Get ONLY the organization IDs the user is authorized to access
        let assignedOrgIds = user.assignedOrgs.map { $0.orgId }
        guard !assignedOrgIds.isEmpty else {
            print("User has no assigned organizations.")
            return
        }
        
        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: Organization.table.name)
        var fetchedOrganizations: [Organization] = []
        
        if let lastUpdatedDate = lastUpdatedDate, !force {
            // Delta Sync: Only fetch the assigned orgs if they've changed
            print("Delta Syncing assigned Orgs since: \(Date(timeIntervalSince1970: lastUpdatedDate))")
            do {
                fetchedOrganizations = try await service.getOrganizations(
                    since: Date(timeIntervalSince1970: lastUpdatedDate),
                    assignedIds: assignedOrgIds
                )
            } catch {
                print("Firestore organization repository error \(error.localizedDescription)")
            }
            
        } else {
            // Full Sync: Fetch each assigned org explicitly and in parallel
            print("Full Syncing assigned Orgs: \(assignedOrgIds)")
            
            try await withThrowingTaskGroup(of: Organization?.self) { group in
                for orgId in assignedOrgIds {
                    group.addTask {
                        do {
                            return try await self.service.getOrganization(for: orgId)
                        } catch {
                            print("Failed to fetch assigned org \(orgId): \(error)")
                            return nil
                        }
                    }
                }
                for try await org in group {
                    if let validOrg = org {
                        fetchedOrganizations.append(validOrg)
                    }
                }
            }
        }
        
        print("Saving \(fetchedOrganizations.count) assigned organizations locally")
        try await storage.saveOrganizations(organizations: fetchedOrganizations)
        
        // Update Sync Timestamp
        guard let orgWithMaxDate = fetchedOrganizations.max(by: { $0.updatedAt < $1.updatedAt }) else { return }
        print("Last updated organization date = \(orgWithMaxDate)")
        try await syncStorage.updateSyncTimestamp(
            for: Organization.table.name,
            timestamp: orgWithMaxDate.updatedAt.timeIntervalSince1970
        )
    }
}
