//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation

public enum CashflowSubCategory: String, Codable, Sendable, CaseIterable {
    case painting = "Painting"
    case woodwork = "Woodwork"
    case salesRevenue = "Sales Revenue"
    case readyStock = "Ready Stock"
    case internalTransfer = "Internal Transfer"
    case poojaFestival = "Pooja/Festival"
    case general = "General"
    case phoneRecharge = "Phone/Recharge"
    case electricity = "Electricity"
    case rent = "Rent"
    case transport = "Transport"
    case food = "Food"
    case cleaning = "Cleaning"
    case otherSetup = "Other Setup"
    case packaging = "Packaging"
    case stationary = "Stationary"
    case online = "Online"
    case ac = "AC"
    case cctv = "CCTV"
    case glassWork = "Glass Work"
    case mobile = "Mobile"
    case internet = "Internet"
    case ceiling = "Ceiling"
    case unknown = "Unknown"
}
