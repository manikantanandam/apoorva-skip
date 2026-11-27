//
//  SyncStatusViewModel.swift
//  ApoorvaModules
//

import Foundation
import SkipFuse
import Observation
import ApoorvaRepository
import ManiLogger

private let logger = AppLogger(category: .sync)

/// Backs the Sync status screen: per-collection status from the `SyncEngine`, plus "Sync now" and
/// "Re-download all". Syncing goes through the app coordinator so Home and other screens reload after.
@MainActor @Observable
public final class SyncStatusViewModel {
    public enum Overall: Equatable {
        case syncing, synced, failed(Int), never
    }

    public private(set) var statuses: [SyncStatus] = []
    public private(set) var isSyncing = false

    private let loadStatuses: () async -> [SyncStatus]
    private let runSync: (_ force: Bool) async -> Void

    public init(loadStatuses: @escaping () async -> [SyncStatus],
                runSync: @escaping (_ force: Bool) async -> Void) {
        self.loadStatuses = loadStatuses
        self.runSync = runSync
    }

    public var failedCount: Int { statuses.filter { $0.lastError != nil }.count }

    public var lastSuccessfulSync: Date? { statuses.compactMap(\.lastSuccess).max() }

    public var overall: Overall {
        if isSyncing || statuses.contains(where: \.isSyncing) { return .syncing }
        if failedCount > 0 { return .failed(failedCount) }
        return lastSuccessfulSync == nil ? .never : .synced
    }

    /// Failed collections first so problems are on top; the rest keep the engine's order.
    public var sortedStatuses: [SyncStatus] {
        statuses.filter { $0.lastError != nil } + statuses.filter { $0.lastError == nil }
    }

    public func load() async {
        statuses = await loadStatuses()
    }

    public func syncNow() async {
        await sync(force: false)
    }

    /// Ignores the stored cursors and fetches every document again.
    public func redownloadAll() async {
        await sync(force: true)
    }

    private func sync(force: Bool) async {
        guard !isSyncing else { return }
        logger.info("Sync status: manual sync force=\(force)")
        isSyncing = true
        await runSync(force)
        statuses = await loadStatuses()
        isSyncing = false
    }

    /// Display name for a sync key: the known collections by name, `org.<collection>` keys from the collection.
    public static func title(for key: String) -> String {
        switch key {
        case "inventory": return "Items"
        case "customers": return "Customers"
        case "sales": return "Bills"
        case "heldBills": return "Held bills"
        case "cashflow": return "Cash entries"
        case "dailyCashflowSummaries": return "Day balances"
        default:
            let collection = key.hasPrefix("org.") ? String(key.dropFirst(4)) : key
            return words(collection)
        }
    }

    /// "salaryPayments" -> "Salary payments".
    static func words(_ camelCase: String) -> String {
        var result = ""
        for character in camelCase {
            if character.isUppercase && !result.isEmpty {
                result += " " + character.lowercased()
            } else {
                result.append(character)
            }
        }
        return result.prefix(1).uppercased() + result.dropFirst()
    }
}
