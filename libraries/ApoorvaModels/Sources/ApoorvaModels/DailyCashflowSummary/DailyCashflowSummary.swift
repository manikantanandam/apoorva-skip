//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation

public struct AccountBalance: Codable, Sendable, Identifiable {
    
    public let id: String
    public let name: String
    public var balance: Double
    
    public init(id: String, name: String, balance: Double) {
        self.id = id
        self.name = name
        self.balance = balance
    }
}

public struct DailyCashflowSummary: Sendable, Codable {
    public let id: String
    public let date: Date
    public let openingBalances: [AccountBalance]
    public let closingBalances: [AccountBalance]
    public let updatedAt: TimeInterval
    public let locked: Bool
    
    // Update the reduce functions to sum the 'balance' property
    public var totalOpening: Double {
        openingBalances.reduce(0) { $0 + $1.balance }
    }
    public var totalClosing: Double {
        closingBalances.reduce(0) { $0 + $1.balance }
    }
    
    public init(date: Date,
                openingBalances: [AccountBalance],
                closingBalances: [AccountBalance],
                updatedAt: TimeInterval,
                locked: Bool) {
        self.date = date
        self.openingBalances = openingBalances
        self.closingBalances = closingBalances
        self.updatedAt = updatedAt
        self.locked = locked
        self.id = date.toString(format: "dd-MM-yyyy")
    }
    
    
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.date = try container.decode(Date.self, forKey: .date)
        self.openingBalances = try container.decode([AccountBalance].self, forKey: .openingBalances)
        self.closingBalances = try container.decodeIfPresent([AccountBalance].self, forKey: .closingBalances) ?? []
        self.updatedAt = try container.decode(TimeInterval.self, forKey: .updatedAt)
        self.locked = try container.decode(Bool.self, forKey: .locked)
    }
    
    public func copyWith(date: Date? = nil,
                         openingBalances: [AccountBalance]? = nil,
                         closingBalances: [AccountBalance]? = nil,
                         updatedAt: TimeInterval? = nil,
                         locked: Bool? = nil) -> DailyCashflowSummary {
        return DailyCashflowSummary(
            date: date ?? self.date,
            openingBalances: openingBalances ?? self.openingBalances,
            closingBalances: closingBalances ?? self.closingBalances,
            updatedAt: updatedAt ?? self.updatedAt,
            locked: locked ?? self.locked)
    }
}
