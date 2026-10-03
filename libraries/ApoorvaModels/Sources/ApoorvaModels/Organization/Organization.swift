import Foundation

public struct Organization: Codable, Sendable {
    public let id: String
    public let name: String
    public let status: String
    public let createdAt: Date
    public let minVersion: String
    public let currentTheme: String
    public let accentColor: String
    public let accounts: [Account]
    
    public var updatedAt: Date
    public var isDeleted: Bool
    
    public enum CodingKeys: String, CodingKey {
        case id, name, status, createdAt, minVersion, currentTheme, accentColor, accounts, updatedAt, isDeleted
    }
    
    // 1. The explicit public memberwise init (Fixes the GRDB error)
    public init(id: String, name: String, status: String, createdAt: Date, minVersion: String, currentTheme: String, accentColor: String, accounts: [Account], updatedAt: Date = Date(), isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.status = status
        self.createdAt = createdAt
        self.minVersion = minVersion
        self.currentTheme = currentTheme
        self.accentColor = accentColor
        self.accounts = accounts
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
    
    // 2. The JSON Decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        self.name = try container.decode(String.self, forKey: .name)
        self.status = try container.decodeIfPresent(String.self, forKey: .status) ?? "Active"
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.minVersion = try container.decodeIfPresent(String.self, forKey: .minVersion) ?? "1.0.0"
        self.currentTheme = try container.decodeIfPresent(String.self, forKey: .currentTheme) ?? "Default"
        self.accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) ?? "#FF5733"
        self.accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
}
