import Foundation

public struct Customer: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let phone: String
    public let createdAt: Date
    public let lastPurchaseDate: Date?
    public let totalSales: Int
    public let totalAmountSpent: Double
    
    public var updatedAt: Date
    public var isDeleted: Bool
    
    public enum CodingKeys: String, CodingKey {
        case name, phone, createdAt, lastPurchaseDate, totalSales, totalAmountSpent, updatedAt, isDeleted
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.phone = try container.decode(String.self, forKey: .phone)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.lastPurchaseDate = try container.decodeIfPresent(Date.self, forKey: .lastPurchaseDate)
        self.totalSales = try container.decodeIfPresent(Int.self, forKey: .totalSales) ?? 0
        self.totalAmountSpent = try container.decodeIfPresent(Double.self, forKey: .totalAmountSpent) ?? 0.0
        
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        self.isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
    
    public var tenure: String {
        let now = Date()
        let components = Calendar.current.dateComponents([.day], from: createdAt, to: now)
        let days = components.day ?? 0
        
        if days < 30 {
            return days == 0 ? "Joined Today" : "Customer for \(days) days"
        } else if days < 365 {
            let months = days / 30
            return "Customer for \(months) month\(months > 1 ? "s" : "")"
        } else {
            let years = days / 365
            let remainingMonths = (days % 365) / 30
            var tenureText = "Customer for \(years) year\(years > 1 ? "s" : "")"
            if remainingMonths > 0 { tenureText += ", \(remainingMonths) month\(remainingMonths > 1 ? "s" : "")" }
            return tenureText
        }
    }
}
