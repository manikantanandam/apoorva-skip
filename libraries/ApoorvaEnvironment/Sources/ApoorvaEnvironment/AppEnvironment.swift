//
//  AppEnvironment.swift
//  ApoorvaUtilities
//

import Foundation
import ApoorvaLogging

private let logger = AppLogger(category: .config)

/// Backend environment the app talks to. Chosen at launch; each has its own Firebase project and local DB file.
public enum AppEnvironment: String, CaseIterable, Codable, Sendable, Identifiable {
    case debug
    case production

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .debug: return "Debug"
        case .production: return "Production"
        }
    }

    /// Pill shown on every screen; `nil` for production.
    public var badge: String? {
        switch self {
        case .debug: return "DEBUG"
        case .production: return nil
        }
    }

    public var firebaseProjectId: String {
        switch self {
        case .debug: return "apoorva-dev"
        case .production: return "apoorva-prod"
        }
    }

    /// Name of the Firebase plist (without extension) bundled with the app.
    public var firebasePlistName: String {
        switch self {
        case .debug: return "GoogleService-Info-debug"
        case .production: return "GoogleService-Info-production"
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
        logger.debug("DEBUG flag set, defaultEnvironment = .debug")
        return .debug
        #else
        logger.debug("DEBUG flag not set, defaultEnvironment = .production")
        return .production
        #endif
    }
}
