//
//  AppSession.swift
//  ApoorvaModules
//

import Foundation
import Observation
import ApoorvaModels
import ApoorvaRepository
import ApoorvaServices
import ApoorvaEnvironment

/// Plan usage for the current month, from local bills plus the org plan config.
public struct PlanStatus: Sendable, Equatable {
    public let tier: OrgSettings.PlanTier
    public let trialDaysLeft: Int
    public let billsUsed: Int
    public let freeBillLimit: Int
    public let graceBills: Int
    public let proPrice: Int

    public var isUnlimited: Bool { tier == .pro || (tier == .trial && trialDaysLeft > 0) }
    public var isOverLimit: Bool { !isUnlimited && billsUsed >= freeBillLimit }
    public var graceUsed: Int { max(0, billsUsed - freeBillLimit) }
    public var graceLeft: Int { max(0, graceBills - graceUsed) }
    /// Free plan near the limit: show the usage banner on Home.
    public var isNearLimit: Bool { !isUnlimited && Double(billsUsed) >= Double(freeBillLimit) * 0.8 }
    public var isTrialEnding: Bool { tier == .trial && trialDaysLeft <= 3 }
}

public enum AccessDecision: Equatable, Sendable {
    case allowed
    case locked(reason: String)
}

/// The signed-in member's world: org settings, current store, role, flags and plan.
/// Screens read it from the environment to hide, guard and label things.
@MainActor
@Observable
public final class AppSession {

    public private(set) var user: AppUser?
    public private(set) var orgId: String?
    public private(set) var settings = OrgSettings()
    public private(set) var hasSettingsDoc = false
    public private(set) var stores: [Store] = []
    public private(set) var currentStoreId: String = Store.defaultId
    public private(set) var member: Member?
    public private(set) var platform = PlatformConfig()
    public private(set) var planStatus = PlanStatus(tier: .trial, trialDaysLeft: 30, billsUsed: 0, freeBillLimit: 100, graceBills: 10, proPrice: 199)
    /// Set by the PIN switch on shared phones; otherwise the signed-in user.
    public private(set) var actingMember: Member?
    /// Sample shop from the demo screen: everything is local and discarded on exit.
    public private(set) var isDemo = false

    private let settingsRepository: any OrgCollectionRepositoryProtocol<OrgSettings>
    private let storeRepository: any OrgCollectionRepositoryProtocol<Store>
    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>
    private let saleRepository: SaleRepositoryProtocol
    private let developerTools: DeveloperToolsProtocol
    private let preferences: UserDefaults

    public init(settingsRepository: any OrgCollectionRepositoryProtocol<OrgSettings>,
                storeRepository: any OrgCollectionRepositoryProtocol<Store>,
                memberRepository: any OrgCollectionRepositoryProtocol<Member>,
                saleRepository: SaleRepositoryProtocol,
                developerTools: DeveloperToolsProtocol,
                preferences: UserDefaults = .standard) {
        self.settingsRepository = settingsRepository
        self.storeRepository = storeRepository
        self.memberRepository = memberRepository
        self.saleRepository = saleRepository
        self.developerTools = developerTools
        self.preferences = preferences
    }

    // MARK: - Identity

    public var currentStore: Store {
        stores.first { $0.id == currentStoreId }
            ?? stores.first
            ?? Store.defaultStore(name: displayShopName, vertical: vertical, billPrefix: settings.profile.billPrefix)
    }

    public var vertical: Vertical {
        stores.first { $0.id == currentStoreId }?.vertical ?? settings.profile.vertical ?? .kirana
    }

    public var displayShopName: String {
        if !settings.profile.shopName.isEmpty { return settings.profile.shopName }
        return user?.selectedOrganization?.name ?? "My Shop"
    }

    public var role: OrgRole {
        if let actingMember { return actingMember.role }
        if let member { return member.role }
        return user.map { OrgRole(appRole: $0.role) } ?? .cashier
    }

    public var actorId: String { actingMember?.id ?? user?.id ?? "" }
    public var actorName: String { actingMember?.name ?? user?.name ?? "" }
    public var isSuperAdmin: Bool { user?.role == .superAdmin }

    // MARK: - Access

    public func can(_ permission: Permission) -> Bool {
        guard isEffectiveMemberActive else { return false }
        return settings.permissions.allows(permission, for: role)
    }

    /// Invited or deactivated members get no permissions. Users without a member doc keep the legacy role.
    private var isEffectiveMemberActive: Bool {
        guard let effective = actingMember ?? member else { return true }
        return effective.isActive && effective.status != "invited"
    }

    public func isOn(_ flag: FeatureFlag) -> Bool {
        resolution(of: flag).isOn
    }

    public func resolution(of flag: FeatureFlag) -> FlagResolution {
        FlagResolver.resolve(flag,
                             app: platform.flags,
                             org: settings.flags.org,
                             store: settings.flags.stores[currentStoreId] ?? [:],
                             role: settings.flags.roles[role.rawValue] ?? [:],
                             developerOverride: developerTools.flagOverrides[flag.rawValue])
    }

    /// Max discount % this role may give without a manager PIN.
    public var discountLimitPercent: Double {
        if role == .owner { return 100 }
        return settings.flags.discountMaxPercentByRole[role.rawValue] ?? 100
    }

    public func access(_ permission: Permission) -> AccessDecision {
        can(permission) ? .allowed : .locked(reason: "\(permission.title) isn't allowed for the \(role.title) role. Ask your owner for access.")
    }

    public func access(_ flag: FeatureFlag) -> AccessDecision {
        let resolution = resolution(of: flag)
        guard !resolution.isOn else { return .allowed }
        if flag.rawValue.hasPrefix("plan.") {
            return .locked(reason: "This is a Pro feature. Upgrade to use it.")
        }
        return .locked(reason: "This feature is turned off for your shop.")
    }

    // MARK: - Loading

    /// Called whenever the session (user/org) changes.
    public func configure(user: AppUser?, platform: PlatformConfig) async {
        self.user = user
        self.platform = platform
        let newOrgId = user?.selectedOrganization?.orgId
        if newOrgId != orgId {
            orgId = newOrgId
            actingMember = nil
            // Drop the previous org's data so a legacy org without a settings doc doesn't inherit it.
            settings = OrgSettings()
            hasSettingsDoc = false
            stores = []
            member = nil
            currentStoreId = preferences.string(forKey: storeKey) ?? Store.defaultId
        }
        await reload()
    }

    public func updatePlatform(_ platform: PlatformConfig) {
        self.platform = platform
        refreshPlanStatus(billsUsed: planStatus.billsUsed)
    }

    /// Re-reads local org data (cheap) — call after sync or after a settings screen saves.
    public func reload() async {
        guard orgId != nil, !isDemo else {
            await refreshPlanUsage()
            return
        }
        if let loaded = try? await settingsRepository.get(id: OrgSettings.documentId) {
            settings = loaded
            hasSettingsDoc = true
        }
        stores = (try? await storeRepository.all())?.sorted { $0.createdAt < $1.createdAt } ?? []
        // A synced-away store must not stay selected: vertical and flags would keep reading its ID.
        if !stores.contains(where: { $0.id == currentStoreId }), let fallback = stores.first {
            selectStore(fallback.id)
        }
        if let uid = user?.id {
            member = try? await memberRepository.get(id: uid)
        }
        await refreshPlanUsage()
    }

    /// Pulls org settings, stores and members from the server, then reloads.
    public func syncOrgData() async {
        try? await settingsRepository.sync(force: false)
        try? await storeRepository.sync(force: false)
        try? await memberRepository.sync(force: false)
        await reload()
    }

    public func refreshPlanUsage() async {
        let sales = (try? await saleRepository.getSales()) ?? []
        let calendar = Calendar.current
        let used = sales.filter {
            !$0.isCancelled && !$0.isReturn && calendar.isDate($0.timestamp, equalTo: Date(), toGranularity: .month)
        }.count
        refreshPlanStatus(billsUsed: used)
    }

    private func refreshPlanStatus(billsUsed: Int) {
        let plan = settings.plan
        let started = plan.trialStartedAt ?? user?.createdAt ?? Date()
        let elapsed = Calendar.current.dateComponents([.day], from: started, to: Date()).day ?? 0
        let tier: OrgSettings.PlanTier = (plan.tier == .trial && elapsed >= platform.trialDays) ? .free : plan.tier
        planStatus = PlanStatus(tier: tier,
                                trialDaysLeft: max(0, platform.trialDays - elapsed),
                                billsUsed: billsUsed,
                                freeBillLimit: platform.freeBillLimit,
                                graceBills: platform.graceBills,
                                proPrice: platform.proPriceMonthly)
    }

    // MARK: - Mutations

    public func saveSettings(_ update: (inout OrgSettings) -> Void) async throws {
        var copy = settings
        update(&copy)
        try await settingsRepository.save(copy)
        settings = copy
        hasSettingsDoc = true
    }

    public func selectStore(_ storeId: String) {
        currentStoreId = storeId
        preferences.set(storeId, forKey: storeKey)
    }

    public func saveStore(_ store: Store) async throws {
        try await storeRepository.save(store)
        await reload()
    }

    public func actAs(_ member: Member?) {
        actingMember = member
    }

    private var storeKey: String { "apoorva.store.\(orgId ?? "none")" }

    // MARK: - Demo

    public func startDemo(user: AppUser, settings: OrgSettings) async {
        isDemo = true
        self.user = user
        orgId = user.selectedOrganization?.orgId
        self.settings = settings
        hasSettingsDoc = true
        stores = []
        member = nil
        actingMember = nil
        await refreshPlanUsage()
    }

    public func endDemo() {
        isDemo = false
        user = nil
        orgId = nil
        settings = OrgSettings()
        hasSettingsDoc = false
    }

    // MARK: - Test support

    /// Seeds state directly (previews and unit tests).
    public func seed(user: AppUser? = nil, settings: OrgSettings? = nil, stores: [Store]? = nil, member: Member? = nil) {
        if let user { self.user = user; orgId = user.selectedOrganization?.orgId }
        if let settings { self.settings = settings; hasSettingsDoc = true }
        if let stores { self.stores = stores }
        if let member { self.member = member }
    }
}
