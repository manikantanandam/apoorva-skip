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
    
    public var isSaving: Bool = false
    public var errorMessage: String?
    
    public let isUpdating: Bool
    
    private let repository: CashflowTransactionRepositoryProtocol
    
    public init(repository: CashflowTransactionRepositoryProtocol,
                existingTransaction: CashflowTransaction? = nil,
                defaultDate: Date = Date()) {
        self.repository = repository
        
        if let tx = existingTransaction {
            self.id = tx.id
            self.timestamp = tx.timestamp
            self.amountText = String(tx.amount)
            self.transactionType = tx.transactionType
            self.paymentMode = tx.paymentMode
            self.category = tx.category
            self.subCategory = tx.subCategory ?? .unknown
            self.particulars = tx.particulars
            self.person = tx.person ?? ""
            self.isUpdating = true
        } else {
            self.id = UUID().uuidString
            self.timestamp = defaultDate
            self.isUpdating = false
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
            person: self.person.isEmpty ? nil : self.person,
            isDeleted: false,
            updatedAt: Date()
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
