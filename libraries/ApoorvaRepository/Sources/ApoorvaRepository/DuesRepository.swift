//
//  DuesRepository.swift
//  ApoorvaRepository
//

import Foundation
import ApoorvaModels

public protocol DuesRepositoryProtocol: Sendable {
    /// Records a payment against a customer's due: ledger entry, lower `dueBalance`, cash in, audit.
    func collect(phone: String, amount: Double, mode: PaymentMode, by actorId: String) async throws -> Customer
    /// A customer's ledger, newest first.
    func ledger(phone: String) async throws -> [CustomerLedgerEntry]
    /// Books money taken up front (order advances) as cash in.
    func recordCashIn(amount: Double, mode: PaymentMode, particulars: String, person: String?, at date: Date) async throws
}

public enum DuesError: Error, Equatable {
    case customerNotFound
    case invalidAmount
}

/// Customer dues: collecting payments, reading the ledger, and booking the cash.
public final actor DuesRepository: DuesRepositoryProtocol {
    private let customerRepository: CustomerRepositoryProtocol
    private let ledgerRepository: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>
    private let cashflowRepository: CashflowTransactionRepositoryProtocol?
    private let audit: AuditLogging?

    public init(customerRepository: CustomerRepositoryProtocol,
                ledgerRepository: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>,
                cashflowRepository: CashflowTransactionRepositoryProtocol?,
                audit: AuditLogging?) {
        self.customerRepository = customerRepository
        self.ledgerRepository = ledgerRepository
        self.cashflowRepository = cashflowRepository
        self.audit = audit
    }

    public func collect(phone: String, amount: Double, mode: PaymentMode, by actorId: String) async throws -> Customer {
        guard amount > 0 else { throw DuesError.invalidAmount }
        guard var customer = try await customerRepository.getCustomer(phone: phone) else { throw DuesError.customerNotFound }
        try await ledgerRepository.save(CustomerLedgerEntry(customerPhone: phone, customerName: customer.name, kind: .payment,
                                                            amount: -amount, mode: mode.rawValue,
                                                            note: "Payment · \(mode.rawValue.uppercased())", createdBy: actorId))
        customer.dueBalance = max(0, customer.dueBalance - amount)
        customer.updatedAt = Date().timeIntervalSince1970
        try await customerRepository.updateCustomer(customer)
        try? await recordCashIn(amount: amount, mode: mode, particulars: "Due collected · \(customer.name)",
                                person: customer.name, at: Date())
        await audit?.log(.money, action: "dues.collect",
                         summary: "Collected ₹\(Int(amount.rounded())) from \(customer.name) by \(mode.rawValue.uppercased())",
                         targetId: phone)
        return customer
    }

    public func ledger(phone: String) async throws -> [CustomerLedgerEntry] {
        try await ledgerRepository.all()
            .filter { $0.customerPhone == phone && !$0.isDeleted }
            .sorted { $0.createdAt > $1.createdAt }
    }

    public func recordCashIn(amount: Double, mode: PaymentMode, particulars: String, person: String?, at date: Date) async throws {
        // Credit isn't money in hand, so it never reaches the cash book.
        guard let cashflowRepository, amount > 0, mode != .credit else { return }
        let account: CashflowTransaction.PaymentMode = mode == .cash ? .cash : .upi
        try await cashflowRepository.saveCashflowTransaction(transaction: CashflowTransaction(
            timestamp: date, particulars: particulars, amount: amount, transactionType: .credit,
            paymentMode: account, category: .salesRevenue, fromAccountId: "", toAccountId: account.accountId,
            person: person, timestampInMs: date.timeIntervalSince1970, updatedAtInMs: Date().timeIntervalSince1970))
    }
}
