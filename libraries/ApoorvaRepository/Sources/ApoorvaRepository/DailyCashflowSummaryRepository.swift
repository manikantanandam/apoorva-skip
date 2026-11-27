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
import ManiLogger

private let logger = AppLogger(category: .sync)

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
        logger.debug("Reading daily cashflow summary from storage \(id)")
        return try await storage.getDailyCashflowSummary(id: id)
    }
    
    public func saveDailyCashflowSummary(summary: DailyCashflowSummary) async throws {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }
        try await service.addDailyCashflowSummary(summary, for: orgId)
        // Cache it now so the day shows straight away, offline too; the next sync upserts the server copy over it.
        try await storage.saveDailyCashflowSummaries(summaries: [summary])
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
        logger.info("Started DailyCashflowSummary sync")
        guard let orgId = try await getOrganizationId() else {
            return
        }
        
        let summaries: [DailyCashflowSummary]
        
        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: DailyCashflowSummary.table.name)
        
        if let lastUpdatedDate, !force {
            summaries = try await service.getDailyCashflowSummaries(since: SyncCursor.queryStart(from: lastUpdatedDate), for: orgId)
        } else {
            summaries = try await service.getDailyCashflowSummaries(for: orgId)
        }

        try await storage.saveDailyCashflowSummaries(summaries: summaries)

        // Advance by the newest record's own `updatedAt`, not this device's clock: another device's
        // write stamped slightly earlier than our "now" would otherwise never be fetched.
        guard let latest = summaries.map(\.updatedAt).max() else { return }
        try await syncStorage.updateSyncTimestamp(for: DailyCashflowSummary.table.name, timestamp: latest)
    }
    
    public func refresh(for date: String) async throws {
        logger.info("Refresh DailyCashflowSummary sync")
        guard let orgId = try await getOrganizationId() else {
            return
        }

        let summary = try await service.getDailyCashflowSummary(orgId: orgId, date: date)
        try await storage.saveDailyCashflowSummary(summary: summary)
        logger.info("Refreshed daily summary for date \(date)")
    }
}

private extension DailyCashflowSummaryRepository {
    func getOrganizationId() async throws -> String? {
        let user = try await userRepository.getCurrentUser()

        return user.selectedOrganization?.orgId
    }
}
