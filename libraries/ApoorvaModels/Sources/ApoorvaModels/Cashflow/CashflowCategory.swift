//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation

/// Raw values match the Apoorva Admin app, which writes the same `cashflow` documents. A category missing here
/// decodes as `.unknown`, so keep this list in step with Admin's `CashflowCategory`.
public enum CashflowCategory: String, Codable, Sendable, CaseIterable {
    case shopSetup = "Shop Setup"
    case salesRevenue = "Sales Revenue"
    case inventory = "Inventory"
    case internalTransfer = "Internal Transfer"
    case maintenanceAndRepairs = "Maintenance & Repairs"
    case miscellaneous = "Miscellaneous"
    case utilities = "Utilities"
    case salary = "Salary"
    case unknown = "Unknown"

    /// Sub-categories that belong to this category, in the order the Admin app offers them.
    public var subCategories: [CashflowSubCategory] {
        switch self {
        case .shopSetup:
            [.woodwork, .painting, .cctv, .glassWork, .otherSetup, .rent, .electricity, .transport, .ceiling, .internet,
             .online, .mobile, .poojaFestival, .food, .stationary, .ac]
        case .inventory: [.rawMaterials, .readyStock, .packaging]
        case .utilities: [.electricity, .internet, .water, .phoneRecharge]
        case .maintenanceAndRepairs: [.repairs, .cleaning, .pestControl, .ceiling, .rent, .poojaFestival, .stationary, .ac]
        case .salary: [.wages, .advances, .bonuses]
        case .salesRevenue: [.salesRevenue]
        case .miscellaneous: [.general, .stationary, .poojaFestival, .petrol, .transport, .food]
        case .internalTransfer: [.internalTransfer]
        case .unknown: []
        }
    }

    /// Categories a person can pick for a cash in/out entry. Internal transfers move money between two accounts,
    /// so they aren't a single cash entry.
    public static var selectable: [CashflowCategory] {
        allCases.filter { $0 != .unknown && $0 != .internalTransfer }
    }
}
