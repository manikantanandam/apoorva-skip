//
//  DailyCashflowSummaryLocalStorage.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL
import ManiLogger

private let logger = AppLogger(category: .storage)

public final actor DailyCashflowSummaryLocalStorage: DailyCashflowSummaryStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getDailyCashflowSummaries() async throws -> [DailyCashflowSummary] {
        logger.debug("Get all summaries")
        do {
            // Fetch all summaries using SkipSQL's native context fetchAll
            let allSummaries: [DailyCashflowSummary] = try await database.withContext { context in
                try context.fetchAll(DailyCashflowSummary.self)
            }
            return allSummaries.sorted { $0.date < $1.date }
        } catch let error {
            if let error = error as? SQLError {
                logger.error("SQL Error:\(error.localizedDescription)")
            }
            return []
        }
    }

    public func getDailyCashflowSummary(id: String) async throws -> DailyCashflowSummary? {
        logger.debug("Fetch daily summary \(id)")
        do {
            return try await database.withContext { context in
                try context.fetch(DailyCashflowSummary.self, primaryKeys: [.text(id)])
            }
        } catch {
            if let error = error as? SQLError {
                logger.error("SQL Error: \(error.msg)")
            }
            throw error
        }

    }

    public func saveDailyCashflowSummary(summary: DailyCashflowSummary) async throws {
        try await database.withContext { context in
            try context.insert(summary)
        }
    }

    public func updateDailyCashflowSummary(summary: DailyCashflowSummary) async throws {
        let query = """
        UPDATE \(DailyCashflowSummary.table.name)
        SET date = ?, openingBalances = ?, closingBalances = ?, updatedAt = ?, locked = ?
        WHERE id = ?;
        """
        logger.debug("Updating summary \(summary.id)")

        try await database.withContext { context in
            try context.exec(sql: query, parameters: [
                .real(summary.date.timeIntervalSince1970),
                .text(summary.openingBalances.string),
                .text(summary.closingBalances.string),
                .real(summary.updatedAt),
                .long(summary.locked.int64Value),
                .text(summary.id)
            ])
        }
    }

    public func deleteDailyCashflowSummary(id: String) async throws {
        let query = "DELETE FROM \(DailyCashflowSummary.table.name) WHERE id = ?;"
        try await database.withContext { context in
            try context.exec(sql: query, parameters: [.text(id)])
        }
    }

    public func saveDailyCashflowSummaries(summaries: [DailyCashflowSummary]) async throws {
        logger.debug("Saving daily cashflow summaries")
        guard !summaries.isEmpty else { return }

        let query = """
        INSERT OR REPLACE INTO \(DailyCashflowSummary.table.name) (
            id, date, openingBalances, closingBalances, updatedAt, locked
        ) VALUES (?, ?, ?, ?, ?, ?);
        """

        do {
            // Wrap bulk inserts in a transaction for performance and safety[cite: 10, 11]
            try await database.withContext { context in
                try context.transaction {
                    for summary in summaries {
                        try context.exec(sql: query, parameters: [
                            .text(summary.id),
                            .real(summary.date.timeIntervalSince1970),
                            .text(summary.openingBalances.string),
                            .text(summary.closingBalances.string),
                            .real(summary.updatedAt),
                            .long(summary.locked.int64Value)
                        ])
                    }
                }
            }
        } catch {
            if let error = error as? SQLError {
                logger.error("Saving daily cashflow summaries failed: \(error.msg)")
            }
            throw error
        }
    }
}
