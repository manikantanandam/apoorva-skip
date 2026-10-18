//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels

public protocol DailyCashflowSummaryStorageProtocol: Sendable {
    func getDailyCashflowSummaries() throws -> [DailyCashflowSummary]
    func getDailyCashflowSummary(id: String) throws -> DailyCashflowSummary?
    func saveDailyCashflowSummary(summary: DailyCashflowSummary) throws
    func updateDailyCashflowSummary(summary: DailyCashflowSummary) throws
    func deleteDailyCashflowSummary(id: String) throws
    func saveDailyCashflowSummaries(summaries: [DailyCashflowSummary]) throws
}
