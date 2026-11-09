import Foundation

public struct Customer: Codable, Sendable, Identifiable, Hashable {
    /// Phone is the stable key: it's the SQLite primary key and the Firestore doc ID.
    public var id: String { phone }
    public var name: String
    public let phone: String
    public let createdAt: TimeInterval
    public var lastPurchaseDate: TimeInterval?
    public var totalSales: Int
    public var totalAmountSpent: Double

    public var creditLimit: Double?
    public var birthday: TimeInterval?
    /// Local cache of what the customer owes, derived from the customer ledger.
    public var dueBalance: Double
    public var priceTier: String?
    public var notes: String?
    public var whatsappReceipts: Bool

    public var updatedAt: TimeInterval?
    public var isDeleted: Bool

    public enum CodingKeys: String, CodingKey {
        case name, phone, createdAt, lastPurchaseDate, totalSales, totalAmountSpent, updatedAt, isDeleted
        case creditLimit, birthday, dueBalance, priceTier, notes, whatsappReceipts
        case documentId = "id"
    }

    public init(name: String,
                phone: String,
                createdAt: TimeInterval,
                lastPurchaseDate: TimeInterval?,
                totalSales: Int,
                totalAmountSpent: Double,
                updatedAt: TimeInterval?,
                isDeleted: Bool,
                creditLimit: Double? = nil,
                birthday: TimeInterval? = nil,
                dueBalance: Double = 0,
                priceTier: String? = nil,
                notes: String? = nil,
                whatsappReceipts: Bool = true) {
        self.name = name
        self.phone = phone
        self.createdAt = createdAt
        self.lastPurchaseDate = lastPurchaseDate
        self.totalSales = totalSales
        self.totalAmountSpent = totalAmountSpent
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
        self.creditLimit = creditLimit
        self.birthday = birthday
        self.dueBalance = dueBalance
        self.priceTier = priceTier
        self.notes = notes
        self.whatsappReceipts = whatsappReceipts
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        let phone = try? container.decodeIfPresent(String.self, forKey: .phone)
        let documentId = try? container.decodeIfPresent(String.self, forKey: .documentId)
        self.phone = phone ?? documentId ?? ""
        let createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        self.createdAt = createdAt?.timeIntervalSince1970 ?? 0

        let lastPurchaseDate = try? container.decodeIfPresent(Date.self, forKey: .lastPurchaseDate)
        self.lastPurchaseDate = lastPurchaseDate?.timeIntervalSince1970

        self.totalSales = (try? container.decodeIfPresent(Int.self, forKey: .totalSales)) ?? 0
        self.totalAmountSpent = (try? container.decodeIfPresent(Double.self, forKey: .totalAmountSpent)) ?? 0.0

        let updatedAt = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)
        self.updatedAt = updatedAt?.timeIntervalSince1970 ?? 0
        self.isDeleted = (try? container.decodeIfPresent(Bool.self, forKey: .isDeleted)) ?? false

        self.creditLimit = try? container.decodeIfPresent(Double.self, forKey: .creditLimit)
        let birthday = try? container.decodeIfPresent(Date.self, forKey: .birthday)
        self.birthday = birthday?.timeIntervalSince1970
        self.dueBalance = (try? container.decodeIfPresent(Double.self, forKey: .dueBalance)) ?? 0
        self.priceTier = try? container.decodeIfPresent(String.self, forKey: .priceTier)
        self.notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        self.whatsappReceipts = (try? container.decodeIfPresent(Bool.self, forKey: .whatsappReceipts)) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(phone, forKey: .phone)
        try container.encode(Date(timeIntervalSince1970: createdAt), forKey: .createdAt)
        try container.encodeIfPresent(lastPurchaseDate.map { Date(timeIntervalSince1970: $0) }, forKey: .lastPurchaseDate)
        try container.encode(totalSales, forKey: .totalSales)
        try container.encode(totalAmountSpent, forKey: .totalAmountSpent)
        try container.encodeIfPresent(updatedAt.map { Date(timeIntervalSince1970: $0) }, forKey: .updatedAt)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encodeIfPresent(creditLimit, forKey: .creditLimit)
        try container.encodeIfPresent(birthday.map { Date(timeIntervalSince1970: $0) }, forKey: .birthday)
        try container.encode(dueBalance, forKey: .dueBalance)
        try container.encodeIfPresent(priceTier, forKey: .priceTier)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(whatsappReceipts, forKey: .whatsappReceipts)
    }
    
    public var tenure: String {
        let now = Date()
        let createdAt = Date(timeIntervalSince1970: createdAt)
        let calendar = Calendar.current
        // Compare calendar days, not elapsed seconds, so a DST change doesn't drop a day.
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: createdAt), to: calendar.startOfDay(for: now))
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
