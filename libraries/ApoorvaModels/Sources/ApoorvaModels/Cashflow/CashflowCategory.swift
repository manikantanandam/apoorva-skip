//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation

public enum CashflowCategory: String, Codable, Sendable, CaseIterable {
    case shopSetup = "Shop Setup"
    case salesRevenue = "Sales Revenue"
    case inventory = "Inventory"
    case internalTransfer = "Internal Transfer"
    case maintenanceAndRepairs = "Maintenance & Repairs"
    case miscellaneous = "Miscellaneous"
    case utilities = "Utilities"
    case unknown = "Unknown"
}
