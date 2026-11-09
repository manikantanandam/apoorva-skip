//
//  SessionPhase.swift
//  ApoorvaModels
//

import Foundation

/// The signed-in account as Firebase Auth reports it, before the profile doc is known.
public struct AuthAccount: Sendable, Equatable {
    public let uid: String
    public let email: String?
    public let isEmailVerified: Bool

    public init(uid: String, email: String?, isEmailVerified: Bool) {
        self.uid = uid
        self.email = email
        self.isEmailVerified = isEmailVerified
    }
}

public enum OrgSetupStep: String, Sendable, Equatable {
    case chooseVertical, shopSetup, pickLook, openingBalances
}

/// Where the app should be, given who's signed in and the state of their org.
public enum SessionPhase: Sendable, Equatable {
    case loading
    case signedOut
    /// Registered with email and not yet verified, with no profile yet.
    case needsEmailVerification(AuthAccount)
    /// Signed in, but there is no `users/{uid}` profile doc yet.
    case needsProfile(AuthAccount)
    /// Has a profile but no org, or an org whose setup wasn't finished.
    case needsOrgSetup(OrgSetupStep)
    case blocked(status: String)
    case forceUpdate(required: String, current: String)
    case ready(userId: String, orgId: String)

    /// Coordinators are rebuilt only when this changes, so routine emissions don't reset navigation.
    public var key: String {
        switch self {
        case .loading: "loading"
        case .signedOut: "signedOut"
        case .needsEmailVerification(let account): "verify:\(account.uid)"
        case .needsProfile(let account): "profile:\(account.uid)"
        case .needsOrgSetup(let step): "setup:\(step.rawValue)"
        case .blocked(let status): "blocked:\(status)"
        case .forceUpdate: "forceUpdate"
        case .ready(let userId, let orgId): "ready:\(userId):\(orgId)"
        }
    }
}

public enum SessionPhaseReducer {
    /// Org statuses that lock staff out (docs/10 console lifecycle).
    public static let blockingStatuses: Set<String> = ["blocked", "suspended", "deleted"]

    public static func phase(account: AuthAccount?,
                             profile: AppUser?,
                             orgStatus: String?,
                             orgSettings: OrgSettings?,
                             platform: PlatformConfig,
                             appVersion: String,
                             requireEmailVerification: Bool) -> SessionPhase {
        guard let account else { return .signedOut }

        if AppVersion(appVersion) < AppVersion(platform.minAppVersion) {
            return .forceUpdate(required: platform.minAppVersion, current: appVersion)
        }

        guard let profile else {
            if requireEmailVerification && account.email != nil && !account.isEmailVerified {
                return .needsEmailVerification(account)
            }
            return .needsProfile(account)
        }

        guard let orgId = profile.selectedOrganization?.orgId else {
            return .needsOrgSetup(.chooseVertical)
        }

        if let status = orgStatus?.lowercased(), blockingStatuses.contains(status), profile.role != .superAdmin {
            return .blocked(status: status)
        }

        // Legacy orgs have no settings doc: they're already set up. Only orgs created by this
        // app's onboarding carry a settings doc that tracks setup progress.
        if let settings = orgSettings, settings.profile.setupCompletedAt == nil {
            if settings.profile.vertical == nil { return .needsOrgSetup(.chooseVertical) }
            if settings.profile.shopName.isEmpty { return .needsOrgSetup(.shopSetup) }
            return .needsOrgSetup(.pickLook)
        }

        return .ready(userId: profile.id, orgId: orgId)
    }
}

/// Dotted numeric version ("1.4.10") with numeric, not lexical, comparison.
public struct AppVersion: Comparable, Sendable {
    public let parts: [Int]

    public init(_ string: String) {
        parts = string.split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.parts.count, rhs.parts.count)
        for index in 0..<count {
            let left = index < lhs.parts.count ? lhs.parts[index] : 0
            let right = index < rhs.parts.count ? rhs.parts[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
