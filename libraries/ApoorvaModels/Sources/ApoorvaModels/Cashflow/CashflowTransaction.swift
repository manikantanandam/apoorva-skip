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
    public var fromAccountId: String
    public var toAccountId: String
    public var person: String?
    public var isDeleted: Bool
    public var updatedAt: Date
    public var timestampInMs: TimeInterval
    public var updatedAtInMs: TimeInterval
    
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
    
    enum CodingKeys: CodingKey {
        case id
        case timestamp
        case particulars
        case amount
        case transactionType
        case paymentMode
        case category
        case subCategory
        case fromAccountId
        case toAccountId
        case person
        case isDeleted
        case updatedAt
        case timestampInMs
        case updatedAtInMs
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.particulars = try container.decode(String.self, forKey: .particulars)
        self.amount = try container.decode(Double.self, forKey: .amount)
        self.transactionType = try container.decode(CashflowTransaction.TransactionType.self, forKey: .transactionType)
        self.paymentMode = try container.decode(CashflowTransaction.PaymentMode.self, forKey: .paymentMode)
        self.category = try container.decode(CashflowCategory.self, forKey: .category)
        self.subCategory = try container.decodeIfPresent(CashflowSubCategory.self, forKey: .subCategory)
        self.fromAccountId = try container.decodeIfPresent(String.self, forKey: .fromAccountId) ?? ""
        self.toAccountId = try container.decodeIfPresent(String.self, forKey: .toAccountId) ?? ""
        self.person = try container.decodeIfPresent(String.self, forKey: .person)
        self.isDeleted = try container.decode(Bool.self, forKey: .isDeleted)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.timestampInMs = try container.decodeIfPresent(TimeInterval.self, forKey: .timestampInMs) ?? 0
        self.updatedAtInMs = try container.decodeIfPresent(TimeInterval.self, forKey: .updatedAtInMs) ?? 0
    }
    
    public init(id: String = UUID().uuidString,
                timestamp: Date,
                particulars: String,
                amount: Double,
                transactionType: TransactionType,
                paymentMode: PaymentMode,
                category: CashflowCategory,
                subCategory: CashflowSubCategory? = nil,
                fromAccountId: String,
                toAccountId: String,
                person: String? = nil,
                isDeleted: Bool = false,
                updatedAt: Date = Date(),
                timestampInMs: TimeInterval,
                updatedAtInMs: TimeInterval
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
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.timestampInMs = timestampInMs
        self.updatedAtInMs = updatedAtInMs
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
