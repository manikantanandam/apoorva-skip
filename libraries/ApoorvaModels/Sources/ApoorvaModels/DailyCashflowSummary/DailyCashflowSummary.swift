//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation

public struct DailyCashflowSummary: Sendable {
    public var id: String {
        date.toString(format: "dd-MM-yyyy")
    }
    public let date: Date
    public let openingCash: Double
    public let openingUpi: Double
    public let closingCash: Double
    public let closingUpi: Double
    
    public var totalOpening: Double { openingCash + openingUpi }
    public var totalClosing: Double { closingCash + closingUpi }
    
    public init(date: Date,
                openingCash: Double,
                openingUpi: Double,
                closingCash: Double,
                closingUpi: Double) {
        self.date = date
        self.openingCash = openingCash
        self.openingUpi = openingUpi
        self.closingCash = closingCash
        self.closingUpi = closingUpi
    }
}
