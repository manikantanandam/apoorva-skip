//
//  DailyCashflowSummaryService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
@preconcurrency import FirebaseFirestore

public protocol DailyCashflowSummaryServiceProtocol: Sendable {

    func getDailyCashflowSummaries(for orgId: String) async throws -> [DailyCashflowSummary]
    func getDailyCashflowSummaries(since lastSync: Date, for orgId: String) async throws -> [DailyCashflowSummary]
    func getDailyCashflowSummary(orgId: String, date: String) async throws -> DailyCashflowSummary
    func addDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws
    func updateDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws
}


public final class DailyCashflowSummaryService: DailyCashflowSummaryServiceProtocol {

    private let store: FirestoreStoring

    private let collectionName = "dailyCashflowSummaries"

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func getDailyCashflowSummaries(for orgId: String) async throws -> [DailyCashflowSummary] {
        try await dailyCashflowTransactions(for: orgId)
    }

    public func getDailyCashflowSummary(orgId: String, date: String) async throws -> DailyCashflowSummary {
        print("🌐 Fetching Daily Cashflow Transactions for Org: \(orgId) for date \(date) ...")
        let path = documentPath(date, orgId: orgId)
        guard let document = try await store.getDocument(path: path) else {
            throw NSError(domain: "DailyCashflowSummaryService", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Daily cashflow summary not found."])
        }
        do {
            return try Firestore.Decoder().decode(DailyCashflowSummary.self, from: document.data)
        } catch {
            print("❌ Failed to decode DailyCashflowSummary: \(document.id) - \(error)")
            throw error
        }
    }

    public func getDailyCashflowSummaries(since lastSync: Date, for orgId: String) async throws -> [DailyCashflowSummary] {
        do {
            return try await dailyCashflowTransactions(since: lastSync, for: orgId)
        } catch {
            print("Eror in fething firestore \(error.localizedDescription)")
            throw error
        }
    }

    public func addDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws {
        let path = documentPath(summary.id, orgId: orgId)

        // Prevent duplicates by checking if the document already exists
        guard try await store.getDocument(path: path) == nil else {
            print("⚠️ Daily Cashflow Summary \(summary.id) already exists. Skipping insertion.")
            return
        }

        try store.set(summary, path: path)
    }

    public func updateDailyCashflowSummary(_ summary: DailyCashflowSummary, for orgId: String) async throws {
        // The model has no `updatedAt` injection, so the data is written as is.
        try store.set(summary, path: documentPath(summary.id, orgId: orgId), merge: true)
    }
}


private extension DailyCashflowSummaryService {
    func collectionPath(orgId: String) -> String {
        "\(String.organizations)/\(orgId)/\(collectionName)"
    }

    func documentPath(_ id: String, orgId: String) -> String {
        "\(collectionPath(orgId: orgId))/\(id)"
    }

    func dailyCashflowTransactions(since lastSync: Date? = nil, for orgId: String) async throws -> [DailyCashflowSummary] {
        var query = StoreQuery.all
        if let lastSync = lastSync {
            query = StoreQuery(conditions: [.greaterThan(field: "updatedAt", date: lastSync)])
        }
        print("🌐 Fetching Daily Cashflow Transactions for Org: \(orgId)...")
        let summaries = try await store.fetch(DailyCashflowSummary.self, collection: collectionPath(orgId: orgId), query: query)
        print("✅ Fetched \(summaries.count) Daily Cashflow Transactions.")
        return summaries
    }
}
