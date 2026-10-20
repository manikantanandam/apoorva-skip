//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels

public protocol DailyCashflowSummaryStorageProtocol: Sendable {
    func getDailyCashflowSummaries()async throws -> [DailyCashflowSummary]
    func getDailyCashflowSummary(id: String)async throws -> DailyCashflowSummary?
    func saveDailyCashflowSummary(summary: DailyCashflowSummary)async throws
    func updateDailyCashflowSummary(summary: DailyCashflowSummary)async throws
    func deleteDailyCashflowSummary(id: String)async throws
    func saveDailyCashflowSummaries(summaries: [DailyCashflowSummary])async throws
}
