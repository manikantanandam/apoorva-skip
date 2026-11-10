//
//  SyncEngine.swift
//  ApoorvaRepository
//

import Foundation
import ApoorvaServices

public struct SyncStatus: Sendable, Equatable {
    public let key: String
    public var lastSuccess: Date?
    public var lastError: String?
    public var isSyncing: Bool

    public init(key: String, lastSuccess: Date? = nil, lastError: String? = nil, isSyncing: Bool = false) {
        self.key = key
        self.lastSuccess = lastSuccess
        self.lastError = lastError
        self.isSyncing = isSyncing
    }
}

/// Runs every registered repository's sync and keeps per-collection status, for the
/// sync chip and the Sync status screen. One collection failing doesn't stop the others.
public actor SyncEngine {

    private var repositories: [any SyncableRepository] = []
    private(set) var statuses: [String: SyncStatus] = [:]
    private let performanceMonitoringService: PerformanceMonitoringServicing
    private let crashReportingService: CrashReportingServicing

    public init(repositories: [any SyncableRepository] = [],
                performanceMonitoringService: PerformanceMonitoringServicing = NoOpPerformanceMonitoringService(),
                crashReportingService: CrashReportingServicing = NoOpCrashReportingService()) {
        self.performanceMonitoringService = performanceMonitoringService
        self.crashReportingService = crashReportingService
        for repository in repositories where !self.repositories.contains(where: { $0.syncKey == repository.syncKey }) {
            self.repositories.append(repository)
            statuses[repository.syncKey] = SyncStatus(key: repository.syncKey)
        }
    }

    public func register(_ repository: any SyncableRepository) {
        guard !repositories.contains(where: { $0.syncKey == repository.syncKey }) else { return }
        repositories.append(repository)
        statuses[repository.syncKey] = SyncStatus(key: repository.syncKey)
    }

    public func register(_ repositories: [any SyncableRepository]) {
        for repository in repositories { register(repository) }
    }

    @discardableResult
    public func syncAll(force: Bool = false) async -> [SyncStatus] {
        for repository in repositories {
            await sync(repository, force: force)
        }
        return allStatuses()
    }

    public func allStatuses() -> [SyncStatus] {
        repositories.compactMap { statuses[$0.syncKey] }
    }

    public var failedCount: Int {
        statuses.values.filter { $0.lastError != nil }.count
    }

    public var lastSuccessfulSync: Date? {
        statuses.values.compactMap(\.lastSuccess).max()
    }

    private func sync(_ repository: any SyncableRepository, force: Bool) async {
        let key = repository.syncKey
        statuses[key, default: SyncStatus(key: key)].isSyncing = true
        do {
            try await performanceMonitoringService.measure("sync_pull") {
                try await repository.sync(force: force)
            }
            statuses[key]?.lastSuccess = Date()
            statuses[key]?.lastError = nil
        } catch {
            statuses[key]?.lastError = error.localizedDescription
            crashReportingService.recordNonFatal(error, context: "sync.\(key)")
        }
        statuses[key]?.isSyncing = false
    }
}
