//
//  AccessAndSessionTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

struct PermissionMatrixTests {
    @Test func standardMatrixMatchesDocs() {
        let matrix = PermissionMatrix.standard
        #expect(matrix.allows(.cancelBill, for: .manager))
        #expect(!matrix.allows(.cancelBill, for: .cashier))
        #expect(matrix.allows(.returns, for: .cashier))
        #expect(matrix.allows(.viewInsights, for: .accountant))
        #expect(!matrix.allows(.createBill, for: .accountant))
        #expect(matrix.allows(.admin, for: .owner))
        #expect(!matrix.allows(.admin, for: .manager))
    }

    @Test func lockedCellsCannotChange() {
        var matrix = PermissionMatrix.standard
        matrix.set(.createBill, for: .cashier, to: false)
        #expect(matrix.allows(.createBill, for: .cashier))
        matrix.set(.admin, for: .manager, to: true)
        #expect(!matrix.allows(.admin, for: .manager))
    }

    @Test func editableCellsChange() {
        var matrix = PermissionMatrix.standard
        matrix.set(.cancelBill, for: .cashier, to: true)
        #expect(matrix.allows(.cancelBill, for: .cashier))
    }

    @Test func decodedMatrixCannotOverrideLockedCells() {
        // Grants come straight from storage, so they can't be trusted to respect the locks.
        let matrix = PermissionMatrix(grants: [
            OrgRole.manager.rawValue: [Permission.admin.rawValue],
            OrgRole.cashier.rawValue: []
        ])
        #expect(!matrix.allows(.admin, for: .manager))
        #expect(matrix.allows(.createBill, for: .cashier))
    }

    @Test func legacyRolesMapToOrgRoles() {
        #expect(OrgRole(appRole: .admin) == .owner)
        #expect(OrgRole(appRole: .manager) == .manager)
        #expect(OrgRole(appRole: .standard) == .cashier)
    }
}

struct ThemeResolverTests {
    private let store = Store(id: "s", name: "Shop", vertical: .fancy)

    @Test func verticalDefaultWhenNothingSet() {
        let theme = ThemeResolver.resolve(org: nil, store: nil, user: UserThemePreference(), vertical: .kirana)
        #expect(theme.accent == .sage)
        #expect(theme.style == .clean)
    }

    @Test func userChoiceBeatsStoreAndOrgWhenNotLocked() {
        let user = UserThemePreference(accent: .rose, style: .bold, useOrgTheme: false)
        let org = OrgSettings.Theme(accent: .ink, style: .clean)
        let theme = ThemeResolver.resolve(org: org, store: store, user: user, vertical: .fancy)
        #expect(theme.accent == .rose)
        #expect(theme.style == .bold)
    }

    @Test func orgLockWinsButKeepsUserScheme() {
        let user = UserThemePreference(accent: .rose, style: .bold, scheme: .dark, useOrgTheme: false)
        let org = OrgSettings.Theme(accent: .ink, style: .clean, locked: true)
        let theme = ThemeResolver.resolve(org: org, store: store, user: user, vertical: .fancy)
        #expect(theme.accent == .ink)
        #expect(theme.style == .clean)
        #expect(theme.scheme == .dark)
        #expect(theme.isLockedByOrg)
    }

    @Test func storeAccentBeatsOrgAccent() {
        var tinted = store
        tinted.accent = .brass
        let theme = ThemeResolver.resolve(org: OrgSettings.Theme(accent: .ink), store: tinted, user: UserThemePreference(), vertical: nil)
        #expect(theme.accent == .brass)
    }

    @Test func orgCanDisableDarkMode() {
        let theme = ThemeResolver.resolve(org: OrgSettings.Theme(allowDark: false), store: nil,
                                          user: UserThemePreference(scheme: .dark), vertical: nil)
        #expect(theme.scheme == .light)
    }
}

struct SessionPhaseReducerTests {
    private let account = AuthAccount(uid: "u1", email: "a@b.com", isEmailVerified: true)

    private func user(orgId: String? = "org1", role: AppUserRole = .admin) -> AppUser {
        AppUser(id: "u1", name: "Kiran", email: "a@b.com", role: role, status: "active", assignedOrgs: [],
                createdAt: Date(),
                selectedOrganization: orgId.map { OrganizationSnapshot(orgId: $0, name: "Shop", accentColor: "#000000") },
                url: "", updatedTimestamp: 0)
    }

    private func phase(account: AuthAccount? = nil, profile: AppUser?, status: String? = "Active",
                       settings: OrgSettings? = nil, minVersion: String = "0.0.0", version: String = "1.0.0",
                       requireVerification: Bool = true) -> SessionPhase {
        SessionPhaseReducer.phase(account: account, profile: profile, orgStatus: status, orgSettings: settings,
                                  minAppVersion: minVersion, appVersion: version,
                                  requireEmailVerification: requireVerification)
    }

    @Test func signedOutWithoutAccount() {
        #expect(phase(profile: nil) == .signedOut)
    }

    @Test func unverifiedEmailWithoutProfileNeedsVerification() {
        let unverified = AuthAccount(uid: "u1", email: "a@b.com", isEmailVerified: false)
        #expect(phase(account: unverified, profile: nil) == .needsEmailVerification(unverified))
        #expect(phase(account: unverified, profile: nil, requireVerification: false) == .needsProfile(unverified))
    }

    @Test func profileWithoutOrgNeedsSetup() {
        #expect(phase(account: account, profile: user(orgId: nil)) == .needsOrgSetup(.chooseVertical))
    }

    @Test func legacyOrgWithoutSettingsIsReady() {
        #expect(phase(account: account, profile: user()) == .ready(userId: "u1", orgId: "org1"))
    }

    @Test func halfFinishedOnboardingResumesAtTheRightStep() {
        var settings = OrgSettings()
        settings.profile.vertical = .fancy
        #expect(phase(account: account, profile: user(), settings: settings) == .needsOrgSetup(.shopSetup))
        settings.profile.shopName = "Glitz"
        #expect(phase(account: account, profile: user(), settings: settings) == .needsOrgSetup(.pickLook))
        settings.profile.setupCompletedAt = Date()
        #expect(phase(account: account, profile: user(), settings: settings) == .ready(userId: "u1", orgId: "org1"))
    }

    @Test func blockedOrgLocksStaffButNotSuperAdmin() {
        #expect(phase(account: account, profile: user(), status: "Suspended") == .blocked(status: "suspended"))
        #expect(phase(account: account, profile: user(role: .superAdmin), status: "blocked") == .ready(userId: "u1", orgId: "org1"))
    }

    @Test func outdatedAppIsForcedToUpdate() {
        #expect(phase(account: account, profile: user(), minVersion: "1.10.0", version: "1.9.3")
                == .forceUpdate(required: "1.10.0", current: "1.9.3"))
    }

    @Test func versionsCompareNumerically() {
        #expect(AppVersion("1.9") < AppVersion("1.10"))
        #expect(AppVersion("2.0.0") == AppVersion("2"))
        #expect(!(AppVersion("1.2.3") < AppVersion("1.2.3")))
    }
}
