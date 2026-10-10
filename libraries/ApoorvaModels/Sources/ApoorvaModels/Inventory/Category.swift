import Foundation

public struct Category: Codable, Sendable, Identifiable {
    // 1. Changed to 'var' so the network layer can inject the Firebase Document ID
    public var id: String
    
    public let name: String
    public let currentStock: Int
    public let billMachineNumber: Int
    public let lastSoldDate: Date?
    public let isHotkey: Bool
    
    public var updatedAt: Date
    public var isDeleted: Bool
    
    // 2. Define standard CodingKeys
    enum CodingKeys: String, CodingKey {
        case id, name, currentStock, billMachineNumber, lastSoldDate, isHotkey, updatedAt, isDeleted
    }
    
    // Standard Initializer
    public init(id: String = UUID().uuidString,
                name: String,
                currentStock: Int = 0,
                billMachineNumber: Int = 0,
                lastSoldDate: Date? = nil,
                isHotkey: Bool = false,
                updatedAt: Date = Date(),
                isDeleted: Bool = false) {
        self.id = id
        self.name = name
        self.currentStock = currentStock
        self.billMachineNumber = billMachineNumber
        self.lastSoldDate = lastSoldDate
        self.isHotkey = isHotkey
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
    
    // 3. The Bulletproof Decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Strings
        self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown Category"
        
        // Numbers
        self.currentStock = (try? container.decodeIfPresent(Int.self, forKey: .currentStock)) ?? 0
        self.billMachineNumber = (try? container.decodeIfPresent(Int.self, forKey: .billMachineNumber)) ?? 0
        
        // Booleans
        self.isHotkey = (try? container.decodeIfPresent(Bool.self, forKey: .isHotkey)) ?? false
        self.isDeleted = (try? container.decodeIfPresent(Bool.self, forKey: .isDeleted)) ?? false
        
        // Dates (If legacy Dart saved these as strings, the 'try?' safely ignores the crash and sets them to nil)
        self.lastSoldDate = try? container.decodeIfPresent(Date.self, forKey: .lastSoldDate)
        self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
    }
}
