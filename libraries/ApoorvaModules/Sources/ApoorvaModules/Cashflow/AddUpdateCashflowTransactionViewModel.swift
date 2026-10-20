// AddUpdateCashflowTransactionViewModel.swift
import Foundation
import SwiftUI
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class AddUpdateCashflowTransactionViewModel {
    public var id: String
    public var timestamp: Date
    public var amountText: String = ""
    public var transactionType: CashflowTransaction.TransactionType = .debit
    public var paymentMode: CashflowTransaction.PaymentMode = .cash
    public var category: CashflowCategory = .miscellaneous
    public var subCategory: CashflowSubCategory = .general
    public var particulars: String = ""
    public var person: String = ""
    
    public var fromAccountId = ""
    public var toAccountId = ""
    
    public var accounts: [Account] = []
    
    public var isSaving: Bool = false
    public var errorMessage: String?
    
    public let isUpdating: Bool
    
    private let repository: CashflowTransactionRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let organizationRepository: OrganizationRepositoryProtocol
    
    public init(repository: CashflowTransactionRepositoryProtocol,
                userRepository: UserRepositoryProtocol,
                organizationRepository: OrganizationRepositoryProtocol,
                existingTransaction: CashflowTransaction? = nil,
                defaultDate: Date = Date()) {
        self.repository = repository
        self.userRepository = userRepository
        self.organizationRepository = organizationRepository
        
        if let tx = existingTransaction {
            print("Existing cashflow transaction \(tx)")
            self.id = tx.id
            self.timestamp = tx.timestamp
            self.amountText = String(tx.amount)
            self.transactionType = tx.transactionType
            self.paymentMode = tx.paymentMode
            self.category = tx.category
            self.subCategory = tx.subCategory ?? .unknown
            self.particulars = tx.particulars
            self.person = tx.person ?? ""
            // We use optional binding with ?? "" to safely handle if the model has nil for these ids
            // Note: Update CashflowTransaction to include fromAccountId/toAccountId if you haven't already.
            self.fromAccountId = tx.fromAccountId
            self.toAccountId = tx.toAccountId
            self.isUpdating = true
        } else {
            self.id = UUID().uuidString
            self.timestamp = defaultDate
            self.isUpdating = false
        }
        
        Task {
            await fetchAccounts()
        }
    }
    
    private func fetchAccounts() async {
        do {
            let user = try await userRepository.getCurrentUser()
            
            guard let orgId = user.selectedOrganization?.orgId else {
                self.errorMessage = "No organization selected."
                return
            }
            
            guard let fullOrganization = try await organizationRepository.getOrganization(orgId: orgId) else {
                self.errorMessage = "Organization details not found."
                return
            }
            
            self.accounts = fullOrganization.accounts
            print("Fetching accounts add update view model \(self.accounts)")
        } catch {
            self.errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }
    }
    
    public func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        
        // Validation
        guard let amount = Double(amountText), amount > 0 else {
            self.errorMessage = "Please enter a valid amount greater than 0."
            return false
        }
        
        // Construct the model
        let transaction = CashflowTransaction(
            id: self.id,
            timestamp: self.timestamp,
            particulars: self.particulars.isEmpty ? "No particulars" : self.particulars,
            amount: amount,
            transactionType: self.transactionType,
            paymentMode: self.paymentMode,
            category: self.category,
            subCategory: self.subCategory == .unknown ? nil : self.subCategory,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            // person: self.person.isEmpty ? nil : self.person,
            isDeleted: false,
            updatedAt: Date(),
            timestampInMs: timestamp.timeIntervalSince1970,
            updatedAtInMs: Date.now.timeIntervalSince1970
        )
        
        do {
            if isUpdating {
                try await repository.updateCashflowTransaction(transaction)
            } else {
                try await repository.saveCashflowTransaction(transaction: transaction)
            }
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
