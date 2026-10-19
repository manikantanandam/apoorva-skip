import Foundation

public struct Customer: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let phone: String
    public let createdAt: TimeInterval
    public let lastPurchaseDate: TimeInterval?
    public let totalSales: Int
    public let totalAmountSpent: Double
    
    public var updatedAt: TimeInterval?
    public var isDeleted: Bool
    
    public enum CodingKeys: String, CodingKey {
        case name, phone, createdAt, lastPurchaseDate, totalSales, totalAmountSpent, updatedAt, isDeleted
    }
    
    public init(name: String,
                phone: String,
                createdAt: TimeInterval,
                lastPurchaseDate: TimeInterval?,
                totalSales: Int,
                totalAmountSpent: Double,
                updatedAt: TimeInterval?,
                isDeleted: Bool) {
        self.id = UUID().uuidString
        self.name = name
        self.phone = phone
        self.createdAt = createdAt
        self.lastPurchaseDate = lastPurchaseDate
        self.totalSales = totalSales
        self.totalAmountSpent = totalAmountSpent
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.phone = try container.decode(String.self, forKey: .phone)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.createdAt = createdAt?.timeIntervalSince1970 ?? 0
        
        let lastPurchaseDate = try container.decodeIfPresent(Date.self, forKey: .lastPurchaseDate)
        self.lastPurchaseDate = lastPurchaseDate?.timeIntervalSince1970
        
        self.totalSales = try container.decodeIfPresent(Int.self, forKey: .totalSales) ?? 0
        self.totalAmountSpent = try container.decodeIfPresent(Double.self, forKey: .totalAmountSpent) ?? 0.0
        
        let updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        self.updatedAt = updatedAt?.timeIntervalSince1970 ?? 0
        self.isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
    }
    
    public var tenure: String {
        let now = Date()
        let createdAt = Date(timeIntervalSince1970: createdAt)
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

extension Customer: Comparable {
    public static func < (lhs: Customer, rhs: Customer) -> Bool {
        return lhs.name < rhs.name
    }
}


public extension Array where Element == Customer {
    var vcfString: String {
        var vcfString = ""
        
        for customer in self {
            let fullName = "\(customer.name) Apoorva Customer"
            
            vcfString += """
                    BEGIN:VCARD
                    VERSION:3.0
                    N:;\(fullName);;;
                    FN:\(fullName)
                    TEL;TYPE=CELL:\(customer.phone)
                    END:VCARD\n
                    """
        }
        return vcfString
    }
    
    var csvString: String {
        var csvString = "Name,Phone\n"
        
        for customer in self {
            // Wraps the name in quotes if it contains a comma to prevent CSV column breaking
            let escapedName = customer.name.contains(",") ? "\"\(customer.name) Apoorva Customer\"" : customer.name
            
            // Appends the name and phone properties from Customer.swift
            csvString += "\(escapedName),\(customer.phone)\n"
        }
        return csvString
    }
}
