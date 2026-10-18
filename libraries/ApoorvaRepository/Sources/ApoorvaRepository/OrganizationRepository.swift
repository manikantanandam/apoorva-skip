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

public final class OrganizationRepository: OrganizationRepositoryProtocol {
    
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
        let organizations = try storage.getOrganizations()
        if organizations.isEmpty {
            try await sync(force: false)
            
            return try storage.getOrganizations()
        }
        
        return organizations
    }
    
    public func getOrganization(orgId: String) async throws -> Organization? {
        var organizations = try storage.getOrganizations()
        if organizations.isEmpty {
            try await sync(force: false)
            
            organizations = try storage.getOrganizations()
        }
        
        return organizations.first(where: { $0.id == orgId })
    }
    
    public func saveOrganization(organization: Organization) async throws {
        try storage.saveOrganization(organization: organization)
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
        
        let lastUpdatedDate = try? syncStorage.getLastSyncTimestamp(for: Organization.table.name)
        var fetchedOrganizations: [Organization] = []
        
        if let lastUpdatedDate = lastUpdatedDate, !force {
            // Delta Sync: Only fetch the assigned orgs if they've changed
            print("Delta Syncing assigned Orgs since: \(Date(timeIntervalSince1970: lastUpdatedDate))")
            fetchedOrganizations = try await service.getOrganizations(
                since: Date(timeIntervalSince1970: lastUpdatedDate),
                assignedIds: assignedOrgIds
            )
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
        try storage.saveOrganizations(organizations: fetchedOrganizations)
        
        // Update Sync Timestamp
        guard let orgWithMaxDate = fetchedOrganizations.max(by: { $0.updatedAt < $1.updatedAt }) else { return }
        print("Last updated organization date = \(orgWithMaxDate)")
        try syncStorage.updateSyncTimestamp(
            for: Organization.table.name,
            timestamp: orgWithMaxDate.updatedAt.timeIntervalSince1970
        )
    }
}
