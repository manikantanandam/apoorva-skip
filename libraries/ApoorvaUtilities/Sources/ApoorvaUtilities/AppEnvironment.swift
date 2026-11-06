//
//  AppEnvironment.swift
//  ApoorvaUtilities
//

import Foundation

/// Backend environment the app talks to. Chosen at launch; each has its own Firebase project and local DB file.
public enum AppEnvironment: String, CaseIterable, Codable, Sendable, Identifiable {
    case dev
    case staging
    case production

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dev: return "Development"
        case .staging: return "Staging"
        case .production: return "Production"
        }
    }

    /// Pill shown on every screen; `nil` for production.
    public var badge: String? {
        switch self {
        case .dev: return "DEV"
        case .staging: return "STG"
        case .production: return nil
        }
    }

    public var firebaseProjectId: String {
        switch self {
        case .dev: return "apoorva-dev"
        case .staging: return "apoorva-stg"
        case .production: return "apoorva-prod"
        }
    }

    /// Name of the Firebase plist (without extension) bundled with the app.
    public var firebasePlistName: String {
        switch self {
        case .dev: return "GoogleService-Info-dev"
        case .staging: return "GoogleService-Info-stg"
        case .production: return "GoogleService-Info"
        }
    }

    /// Destructive local tools (seed, clear DB) are never offered on production.
    public var allowsDestructiveTools: Bool { self != .production }

    public func dbFileName(orgId: String? = nil) -> String {
        if let orgId, !orgId.isEmpty {
            return "apoorva-\(rawValue)-\(orgId).db"
        }
        return "apoorva-\(rawValue).db"
    }

    public static var defaultEnvironment: AppEnvironment {
        #if DEBUG
        return .dev
        #else
        return .production
        #endif
    }
}
