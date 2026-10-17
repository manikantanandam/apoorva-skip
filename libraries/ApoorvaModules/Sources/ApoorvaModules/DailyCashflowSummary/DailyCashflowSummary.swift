//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation
import ApoorvaModels

public struct DailyCashflowSummary: Sendable {
    public let date: Date
    public let openingCash: Double
    public let openingUpi: Double
    public let closingCash: Double
    public let closingUpi: Double
    public let transactions: [CashflowTransaction]
    
    public var totalOpening: Double { openingCash + openingUpi }
    public var totalClosing: Double { closingCash + closingUpi }
    
    public init(date: Date,
                openingCash: Double,
                openingUpi: Double,
                closingCash: Double,
                closingUpi: Double,
                transactions: [CashflowTransaction]) {
        self.date = date
        self.openingCash = openingCash
        self.openingUpi = openingUpi
        self.closingCash = closingCash
        self.closingUpi = closingUpi
        self.transactions = transactions
    }
}
