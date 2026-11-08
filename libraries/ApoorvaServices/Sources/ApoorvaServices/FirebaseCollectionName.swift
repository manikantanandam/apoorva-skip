//
//  File.swift
//  ApoorvaServices
//
//  Created by Manikanta Nandam on 11/10/26.
//

import Foundation

internal extension String {
    static let users = "users"
    static let inventory = "inventory"
    static let organizations = "organizations"
    static let customers = "customers"
    static let sales = "sales"
    static let cashflow = "cashflow"
    static let heldBills = "heldBills"

    /// Path of a sub-collection of an organization, e.g. `organizations/{orgId}/sales`.
    static func orgPath(_ orgId: String, _ collection: String) -> String {
        "\(organizations)/\(orgId)/\(collection)"
    }
}
