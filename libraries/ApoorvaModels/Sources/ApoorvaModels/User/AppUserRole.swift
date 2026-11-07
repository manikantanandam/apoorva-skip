//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation

public enum AppUserRole: String, Codable, Sendable, CaseIterable {
    case standard // Assuming this is your default
    case admin
    case manager
    case superAdmin = "super_admin"
    // Add other roles as needed
}

public extension AppUserRole {
    var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .admin: return "Admin"
        case .manager: return "Manager"
        case .superAdmin: return "Super Admin"
        }
    }
}
