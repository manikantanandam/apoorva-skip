//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation

public struct AccountBalance: Codable, Sendable, Identifiable {
    
    public let id: String
    public var balance: Double
    
    public init(id: String, balance: Double) {
        self.id = id
        self.balance = balance
    }
}

public struct DailyCashflowSummary: Sendable, Codable {
    public var id: String {
        date.toString(format: "dd-MM-yyyy")
    }
    public let date: Date
    public let openingBalances: [AccountBalance]
    public let closingBalances: [AccountBalance]
    
    // Update the reduce functions to sum the 'balance' property
    public var totalOpening: Double {
        openingBalances.reduce(0) { $0 + $1.balance }
    }
    public var totalClosing: Double {
        closingBalances.reduce(0) { $0 + $1.balance }
    }
    
    public init(date: Date,
                openingBalances: [AccountBalance],
                closingBalances: [AccountBalance]) {
        self.date = date
        self.openingBalances = openingBalances
        self.closingBalances = closingBalances
    }
}
