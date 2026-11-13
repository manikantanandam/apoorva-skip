//
//  CashflowTransactionService.swift
//  ApoorvaServices
//

import Foundation
import ApoorvaModels
import ApoorvaLogging

private let logger = AppLogger(category: .network)

public protocol CashflowTransactionServiceProtocol: Sendable {

    func getCashflowTransactions(for orgId: String) async throws -> [CashflowTransaction]
    func getCashflowTransactions(since lastSync: Date, for orgId: String) async throws -> [CashflowTransaction]
    func addCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws
    func updateCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws
}


public final class CashflowTransactionService: CashflowTransactionServiceProtocol {

    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func getCashflowTransactions(for orgId: String) async throws -> [CashflowTransaction] {
        try await cashflowTransactions(for: orgId)
    }

    public func getCashflowTransactions(since lastSync: Date, for orgId: String) async throws -> [CashflowTransaction] {
        try await cashflowTransactions(since: lastSync, for: orgId)
    }

    public func addCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws {
        let path = documentPath(transaction.id, orgId: orgId)

        // Prevent duplicates by checking if the document already exists
        guard try await store.getDocument(path: path) == nil else {
            logger.warning("Cashflow Transaction \(transaction.id) already exists. Skipping insertion.")
            return
        }

        try store.set(transaction, path: path)
    }

    public func updateCashflowTransaction(_ transaction: CashflowTransaction, for orgId: String) async throws {
        var updatedTransaction = transaction
        let now = Date.now
        updatedTransaction.updatedAt = now
        updatedTransaction.updatedAtInMs = now.timeIntervalSince1970

        try store.set(updatedTransaction, path: documentPath(transaction.id, orgId: orgId), merge: true)
    }

    public func deleteCashflowTransaction(id: String, for orgId: String) async throws {
        // Soft-delete to keep offline sync working via the isDeleted flag
        try await store.updateData([
            "isDeleted": true,
            "updatedAt": Date()
        ], path: documentPath(id, orgId: orgId))
    }
}

private extension CashflowTransactionService {
    func documentPath(_ id: String, orgId: String) -> String {
        "\(String.orgPath(orgId, .cashflow))/\(id)"
    }

    func cashflowTransactions(since lastSync: Date? = nil, for orgId: String) async throws -> [CashflowTransaction] {
        var query = StoreQuery.all
        if let lastSync = lastSync {
            query = StoreQuery(conditions: [.greaterThan(field: "updatedAt", date: lastSync)])
        }
        logger.debug("Fetching Cashflow Transactions for Org: \(orgId)")
        let records = try await store.fetch(CashflowTransaction.self, collection: .orgPath(orgId, .cashflow), query: query)
        logger.info("Fetched \(records.count) Cashflow Transactions")
        return records
    }
}
