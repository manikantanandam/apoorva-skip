//
//  DuesRepositoryTests.swift
//  ApoorvaRepository
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaOfflineStorage
@testable import ApoorvaServices
@testable import ApoorvaRepository

final class RecordingCashflowRepository: CashflowTransactionRepositoryProtocol, @unchecked Sendable {
    var saved: [CashflowTransaction] = []
    func getCashflowTransactions() async throws -> [CashflowTransaction] { saved }
    func saveCashflowTransaction(transaction: CashflowTransaction) async throws { saved.append(transaction) }
    func updateCashflowTransaction(_ transaction: CashflowTransaction) async throws {}
    func deleteCashflowTransaction(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws {}
}

struct DuesRepositoryTests {
    private func makeSUT(due: Double) throws -> (DuesRepository, LifecycleCustomerRepository, OrgCollectionRepository<CustomerLedgerEntry>,
                                                  RecordingCashflowRepository, RecordingAudit) {
        let database = try SkipSqlDatabase(filepath: ":memory:")
        let ledger = OrgCollectionRepository<CustomerLedgerEntry>(storage: OrgCollectionLocalStorage(database: database),
                                                                  service: OrgCollectionService(store: InMemoryStore()),
                                                                  context: FixedOrgContext(orgId: nil), syncStorage: SyncStorage(db: database))
        let customers = LifecycleCustomerRepository()
        customers.customers["9"] = Customer(name: "Meena S", phone: "9", createdAt: 0, lastPurchaseDate: nil, totalSales: 3,
                                            totalAmountSpent: 0, updatedAt: nil, isDeleted: false, dueBalance: due)
        let cashflow = RecordingCashflowRepository()
        let audit = RecordingAudit()
        let dues = DuesRepository(customerRepository: customers, ledgerRepository: ledger, cashflowRepository: cashflow, audit: audit)
        return (dues, customers, ledger, cashflow, audit)
    }

    @Test func collectingWritesLedgerLowersDueAndBooksCash() async throws {
        let (dues, customers, ledger, cashflow, audit) = try makeSUT(due: 1120)
        let customer = try await dues.collect(phone: "9", amount: 800, mode: .upi, by: "u1")

        #expect(customer.dueBalance == 320)
        #expect(customers.customers["9"]?.dueBalance == 320)
        let entries = try await ledger.all()
        #expect(entries.first?.amount == -800)
        #expect(entries.first?.kind == .payment)
        #expect(cashflow.saved.first?.amount == 800)
        #expect(cashflow.saved.first?.paymentMode == .upi)
        #expect(audit.box.actions == ["dues.collect"])
        #expect(try await dues.ledger(phone: "9").count == 1)
    }

    @Test func rejectsBadAmountsAndUnknownCustomers() async throws {
        let (dues, _, _, _, _) = try makeSUT(due: 100)
        await #expect(throws: DuesError.invalidAmount) { try await dues.collect(phone: "9", amount: 0, mode: .cash, by: "u1") }
        await #expect(throws: DuesError.customerNotFound) { try await dues.collect(phone: "1", amount: 10, mode: .cash, by: "u1") }
    }

    @Test func creditIsNeverBookedAsCash() async throws {
        let (dues, _, _, cashflow, _) = try makeSUT(due: 0)
        try await dues.recordCashIn(amount: 500, mode: .credit, particulars: "x", person: nil, at: Date())
        try await dues.recordCashIn(amount: 500, mode: .cash, particulars: "Advance", person: nil, at: Date())
        #expect(cashflow.saved.count == 1)
        #expect(cashflow.saved.first?.paymentMode == .cash)
    }
}
