//
//  DailyCashflowSummaryLocalStorage.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

public final actor DailyCashflowSummaryLocalStorage: DailyCashflowSummaryStorageProtocol {
    
    private let database: SkipSqlDatabase
    
    public init(database: SkipSqlDatabase) {
        self.database = database
    }
    
    public func getDailyCashflowSummaries() throws -> [DailyCashflowSummary] {
        print("get all summaries")
        do {
            // Fetch all summaries using SkipSQL's native context fetchAll
            let allSummaries: [DailyCashflowSummary] = try database.context.fetchAll(DailyCashflowSummary.self)
            return allSummaries.sorted { $0.date < $1.date }
        } catch let error {
            if let error = error as? SQLError {
                print("SQL Error: \(error.localizedDescription)")
            }
            return []
        }
    }
    
    public func getDailyCashflowSummary(id: String) throws -> DailyCashflowSummary? {
        print("cashflow id fetch \(id)")
        do {
            return try database.context.fetch(DailyCashflowSummary.self, primaryKeys: [.text(id)])
        } catch {
            if let error = error as? SQLError {
                print(error.msg)
            }
            throw error
        }
        
    }
    
    public func saveDailyCashflowSummary(summary: DailyCashflowSummary) throws {
        try database.context.insert(summary)

    }
    
    public func updateDailyCashflowSummary(summary: DailyCashflowSummary) throws {
        let query = """
        UPDATE \(DailyCashflowSummary.table.name)
        SET date = ?, openingBalances = ?, closingBalances = ?, updatedAt = ?, locked = ?
        WHERE id = ?;
        """
        print("Updating the summary \(summary) for \(summary.id)")
        
        try database.context.exec(sql: query, parameters: [
            .real(summary.date.timeIntervalSince1970),
            .text(summary.openingBalances.string),
            .text(summary.closingBalances.string),
            .real(summary.updatedAt),
            .long(summary.locked.int64Value),
            .text(summary.id)
        ])
    }
    
    public func deleteDailyCashflowSummary(id: String) throws {
        let query = "DELETE FROM \(DailyCashflowSummary.table.name) WHERE id = ?;"
        try database.context.exec(sql: query, parameters: [.text(id)])
    }
    
    public func saveDailyCashflowSummaries(summaries: [DailyCashflowSummary]) throws {
        print("Saving daily cash flow summaries")
        guard !summaries.isEmpty else { return }
        
        let query = """
        INSERT OR REPLACE INTO \(DailyCashflowSummary.table.name) (
            id, date, openingBalances, closingBalances, updatedAt, locked
        ) VALUES (?, ?, ?, ?, ?, ?);
        """
        
        // Wrap bulk inserts in a transaction for performance and safety[cite: 10, 11]
        try database.context.exec(sql: "BEGIN TRANSACTION;")
        
        do {
            for summary in summaries {
                try database.context.exec(sql: query, parameters: [
                    .text(summary.id),
                    .real(summary.date.timeIntervalSince1970),
                    .text(summary.openingBalances.string),
                    .text(summary.closingBalances.string),
                    .real(summary.updatedAt),
                    .long(summary.locked.int64Value)
                ])
            }
            try database.context.exec(sql: "COMMIT;")
        } catch {
            // Rollback the transaction if any insert fails[cite: 10, 11]
            try? database.context.exec(sql: "ROLLBACK;")
            if let error = error as? SQLError {
                print("Saving daily cashflow summaries failed: \(error.msg)")
            }
            throw error
        }
    }
}
