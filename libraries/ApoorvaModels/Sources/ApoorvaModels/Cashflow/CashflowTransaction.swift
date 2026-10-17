import Foundation

public struct CashflowTransaction: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var timestamp: Date
    public var particulars: String
    public var amount: Double
    public var transactionType: TransactionType
    public var paymentMode: PaymentMode
    public var category: CashflowCategory
    public var subCategory: CashflowSubCategory?
    public var person: String?
    public var isDeleted: Bool
    public var updatedAt: Date
    
    public enum TransactionType: String, Codable, Sendable {
        case credit
        case debit
        case unknown
    }
    
    public enum PaymentMode: String, Codable, Sendable {
        case cash
        case upi
        case unknown
    }
    
    public init(id: String = UUID().uuidString,
                timestamp: Date,
                particulars: String,
                amount: Double,
                transactionType: TransactionType,
                paymentMode: PaymentMode,
                category: CashflowCategory,
                subCategory: CashflowSubCategory? = nil,
                person: String? = nil,
                isDeleted: Bool = false,
                updatedAt: Date = Date()
    ) {
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

extension CashflowTransaction: Comparable {
    public static func == (lhs: borrowing CashflowTransaction, rhs: borrowing CashflowTransaction) -> Bool {
        return lhs.id == rhs.id
    }
    
    public static func < (lhs: CashflowTransaction, rhs: CashflowTransaction) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
    
    public static func > (lhs: CashflowTransaction, rhs: CashflowTransaction) -> Bool {
        return lhs.timestamp > rhs.timestamp
    }
}
