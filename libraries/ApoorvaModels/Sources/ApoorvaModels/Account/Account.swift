import Foundation

public enum AccountType: String, Codable, Sendable {
    case cash
    case bank
    case upi
}

public struct Account: Codable, Sendable {
    public let id: String
    public let name: String
    public let type: AccountType
    public let currentBalance: Double
    
    // Sync fields for Delta Engine
    public var updatedAt: Date
    public var isDeleted: Bool
    
    public enum CodingKeys: String, CodingKey {
        case id, name, type, currentBalance, updatedAt, isDeleted
    }
    
    // Standard initializer
    public init(id: String = UUID().uuidString, name: String, type: AccountType, currentBalance: Double, updatedAt: Date = Date(), isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.currentBalance = currentBalance
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
    
    // Decoder to handle the fallback UUID logic and default sync fields
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(AccountType.self, forKey: .type)
        self.currentBalance = try container.decode(Double.self, forKey: .currentBalance)
        
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}
