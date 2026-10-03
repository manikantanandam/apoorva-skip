import Foundation

public struct CashflowTransaction: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var timestamp: Date
    public var particulars: String
    public var amount: Double
    public var transactionType: TransactionType
    public var paymentMode: PaymentMode
    public var category: String
    public var subCategory: String?
    public var person: String?
    public var isDeleted: Bool
    public var updatedAt: Date
    
    public enum TransactionType: String, Codable, Sendable {
        case credit
        case debit
    }
    
    public enum PaymentMode: String, Codable, Sendable {
        case cash
        case upi
    }
    
    public init(id: String = UUID().uuidString, timestamp: Date, particulars: String, amount: Double, transactionType: TransactionType, paymentMode: PaymentMode, category: String, subCategory: String? = nil, person: String? = nil, isDeleted: Bool = false, updatedAt: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
        self.particulars = particulars
        self.amount = amount
        self.transactionType = transactionType
        self.paymentMode = paymentMode
        self.category = category
        self.subCategory = subCategory
        self.person = person
        self.isDeleted = isDeleted
        self.updatedAt = updatedAt
    }
}
