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
    func refresh(for date: String) async throws
}

public final actor DailyCashflowSummaryRepository: DailyCashflowSummaryRepositoryProtocol {

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
        print("reading daily cashflow from storage \(id)")
        return try await storage.getDailyCashflowSummary(id: id)
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
        guard let orgId = try await getOrganizationId() else {
            return
        }
        
        let summaries: [DailyCashflowSummary]
        
        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: DailyCashflowSummary.table.name)
        
        if let lastUpdatedDate, !force {
            summaries = try await service.getDailyCashflowSummaries(since: lastUpdatedDate.date, for: orgId)
        } else {
            summaries = try await service.getDailyCashflowSummaries(for: orgId)
        }
        
        try await storage.saveDailyCashflowSummaries(summaries: summaries)

        try await syncStorage.updateSyncTimestamp(
            for: DailyCashflowSummary.table.name,
            timestamp: Date.now.timeIntervalSince1970
        )
    }
    
    public func refresh(for date: String) async throws {
        print("Refresh DailyCashflowSummary sync")
        guard let orgId = try await getOrganizationId() else {
            return
        }

        let summary = try await service.getDailyCashflowSummary(orgId: orgId, date: date)
        try await storage.saveDailyCashflowSummary(summary: summary)
        print("Refreshed daily summary for date \(date):  \(summary)")
    }
}

private extension DailyCashflowSummaryRepository {
    func getOrganizationId() async throws -> String? {
        let user = try await userRepository.getCurrentUser()

        return user.selectedOrganization?.orgId
    }
}
