import Foundation

public struct InternalTransfer: Codable, Sendable {
    public let id: String
    public let fromAccountId: String
    public let toAccountId: String
    public let amount: Double
    public let transferType: String
    public let timestamp: Date
    
    // Sync fields for Delta Engine
    public var updatedAt: Date
    public var isDeleted: Bool
    
    public init(id: String, fromAccountId: String, toAccountId: String, amount: Double, transferType: String, timestamp: Date, updatedAt: Date = Date(), isDeleted: Bool = false) {
        self.id = id
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.amount = amount
        self.transferType = transferType
        self.timestamp = timestamp
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
}
