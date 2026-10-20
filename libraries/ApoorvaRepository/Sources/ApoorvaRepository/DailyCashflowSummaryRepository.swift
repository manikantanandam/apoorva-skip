//
//  DailyCashflowSummaryRepository.swift
//  ApoorvaRepository
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaOfflineStorage
import ApoorvaModels
import ApoorvaServices

public protocol DailyCashflowSummaryRepositoryProtocol: Sendable {
    func getDailyCashflowSummaries() async throws -> [DailyCashflowSummary]
    func getDailyCashflowSummary(id: String) async throws -> DailyCashflowSummary?
    func saveDailyCashflowSummary(summary: DailyCashflowSummary) async throws
    func updateDailyCashflowSummary(summary: DailyCashflowSummary) async throws
    func deleteDailyCashflowSummary(id: String) async throws
    func sync(force: Bool) async throws
}

public final class DailyCashflowSummaryRepository: DailyCashflowSummaryRepositoryProtocol {

    let storage: DailyCashflowSummaryStorageProtocol
    let service: DailyCashflowSummaryServiceProtocol
    let userRepository: UserRepositoryProtocol
    let syncStorage: SyncStorage
    
    public init(
        storage: DailyCashflowSummaryStorageProtocol,
        service: DailyCashflowSummaryServiceProtocol,
        userRepository: UserRepositoryProtocol,
        syncStorage: SyncStorage
    ) {
        self.storage = storage
        self.service = service
        self.userRepository = userRepository
        self.syncStorage = syncStorage
    }
    
    public func getDailyCashflowSummaries() async throws -> [DailyCashflowSummary] {
        try await storage.getDailyCashflowSummaries()
    }
    
    public func getDailyCashflowSummary(id: String) async throws -> DailyCashflowSummary? {
        try await storage.getDailyCashflowSummary(id: id)
    }
    
    public func saveDailyCashflowSummary(summary: DailyCashflowSummary) async throws {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }
        try await service.addDailyCashflowSummary(summary, for: orgId)
        // Note: Skipping local storage save here to let the sync mechanism handle it, matching the pattern in CashflowTransactionRepository.
    }
    
    public func updateDailyCashflowSummary(summary: DailyCashflowSummary) async throws {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }
        try await service.updateDailyCashflowSummary(summary, for: orgId)
        try await storage.updateDailyCashflowSummary(summary: summary)
    }
    
    public func deleteDailyCashflowSummary(id: String) async throws {
        try await storage.deleteDailyCashflowSummary(id: id)
    }
    
    public func sync(force: Bool) async throws {
        print("Started DailyCashflowSummary sync")
        let user = try await userRepository.getCurrentUser()
        print("Received user")

        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }
        
        // Note: Because the DailyCashflowSummary model lacks an `updatedAt` field, and the service lacks a delta fetch method, a full sync is performed every time.[cite: 19, 20]
        print("Fetch all daily cashflow summaries for \(orgId)")
        let summaries = try await service.getDailyCashflowSummaries(for: orgId)
        
        print("Saving daily cashflow summaries")
        try await storage.saveDailyCashflowSummaries(summaries: summaries)
        
        // Update the sync timestamp using the current time since we don't have a model-level updatedAt.
        try await syncStorage.updateSyncTimestamp(
            for: DailyCashflowSummary.table.name,
            timestamp: Date().timeIntervalSince1970
        )
    }
}
