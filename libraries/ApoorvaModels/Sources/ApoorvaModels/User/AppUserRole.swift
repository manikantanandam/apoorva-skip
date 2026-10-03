//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation

public enum AppUserRole: String, Codable, Sendable {
    case standard // Assuming this is your default
    case admin
    case manager
    case superAdmin = "super_admin"
    // Add other roles as needed
}
