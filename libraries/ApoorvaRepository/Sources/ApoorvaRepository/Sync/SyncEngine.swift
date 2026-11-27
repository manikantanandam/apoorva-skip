//
//  SyncEngine.swift
//  ApoorvaRepository
//

import Foundation
import ApoorvaServices
import ManiLogger

private let logger = AppLogger(category: .sync)

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
    /// The pass in progress. Launch, foreground and pull-to-refresh can all ask at once; they share one pass.
    private var inFlight: Task<[SyncStatus], Never>?
    private let performanceMonitoringService: PerformanceMonitoringServicing
    private let crashReportingService: CrashReportingServicing
    private let analyticsService: AnalyticsServicing

    public init(repositories: [any SyncableRepository] = [],
                performanceMonitoringService: PerformanceMonitoringServicing = NoOpPerformanceMonitoringService(),
                crashReportingService: CrashReportingServicing = NoOpCrashReportingService(),
                analyticsService: AnalyticsServicing = NoOpAnalyticsService()) {
        self.performanceMonitoringService = performanceMonitoringService
        self.crashReportingService = crashReportingService
        self.analyticsService = analyticsService
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

    /// Joins a pass already running instead of starting a second one. A forced call waits for it,
    /// then runs its own full pass, so "re-download everything" is never swallowed by a delta pass.
    @discardableResult
    public func syncAll(force: Bool = false) async -> [SyncStatus] {
        if let running = inFlight {
            let result = await running.value
            if !force { return result }
        }
        let task = Task { await runAll(force: force) }
        inFlight = task
        let result = await task.value
        // A forced caller may have started a newer pass while this one finished; leave that one in place.
        if inFlight == task { inFlight = nil }
        return result
    }

    public var isSyncing: Bool { inFlight != nil }

    public func allStatuses() -> [SyncStatus] {
        repositories.compactMap { statuses[$0.syncKey] }
    }

    private func runAll(force: Bool) async -> [SyncStatus] {
        let start = Date()
        for repository in repositories {
            await sync(repository, force: force)
        }
        analyticsService.log(.syncCompleted(durationMs: Int(Date().timeIntervalSince(start) * 1000),
                                            collectionCount: repositories.count, failedCount: failedCount))
        return allStatuses()
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
            logger.error("sync failed key=\(key): \(error)")
            crashReportingService.recordNonFatal(error, context: "sync.\(key)")
            analyticsService.log(.syncFailed(collection: key, reason: String(describing: type(of: error))))
        }
        statuses[key]?.isSyncing = false
    }
}
