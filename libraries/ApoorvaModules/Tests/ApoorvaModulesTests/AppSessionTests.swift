//
//  AppSessionTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
import ApoorvaEnvironment
@testable import ApoorvaModules

/// In-memory stand-in for any org collection repository.
final class StubOrgRepository<Document: OrgDocument>: OrgCollectionRepositoryProtocol, @unchecked Sendable {
    var documents: [String: Document] = [:]
    let syncKey = "stub"

    init(_ documents: [Document] = []) {
        for document in documents { self.documents[document.id] = document }
    }

    func all() async throws -> [Document] { Array(documents.values) }
    func get(id: String) async throws -> Document? { documents[id] }
    func save(_ document: Document) async throws { documents[document.id] = document }
    func saveAll(_ documents: [Document]) async throws { for document in documents { self.documents[document.id] = document } }
    func delete(id: String) async throws { documents[id] = nil }
    func changes() async -> AsyncStream<Void> { AsyncStream { $0.finish() } }
    func sync(force: Bool) async throws {}
}

final class StubSaleRepository: SaleRepositoryProtocol, @unchecked Sendable {
    var sales: [Sale] = []
    func getSales() async throws -> [Sale] { sales }
    func getSale(id: String) async throws -> Sale? { sales.first { $0.id == id } }
    func saveSale(sale: Sale) async throws { sales.append(sale) }
    func updateSale(_ sale: Sale) async throws {}
    func deleteSale(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func confirmSale(_ sale: Sale, heldBillId: String?) async throws { sales.append(sale) }
    func cancelSale(id: String, reason: String, by staffId: String) async throws -> Sale? { nil }
    func editSale(_ sale: Sale, reason: String) async throws {}
    func sync(force: Bool) async throws {}
}

final class StubDeveloperTools: DeveloperToolsProtocol, @unchecked Sendable {
    var flagOverrides: [String: Bool] = [:]
    func setFlagOverride(_ key: String, value: Bool?) { flagOverrides[key] = value }
    func clearFlagOverrides() { flagOverrides = [:] }
    var isOfflineSimulated = false
    var showsScreenIdentifiers = false
}

func makeSessionUser(role: AppUserRole = .admin) -> AppUser {
    AppUser(id: "u1", name: "Kiran", email: "k@shop.in", role: role, status: "active", assignedOrgs: [],
            createdAt: Date(), selectedOrganization: OrganizationSnapshot(orgId: "org1", name: "Glitz Gifts"))
}

@MainActor
struct AppSessionTests {

    private func makeSession(settings: OrgSettings? = nil, sales: [Sale] = [], tools: StubDeveloperTools = StubDeveloperTools())
    -> AppSession {
        let saleRepository = StubSaleRepository()
        saleRepository.sales = sales
        return AppSession(
            settingsRepository: StubOrgRepository<OrgSettings>(settings.map { [$0] } ?? []),
            storeRepository: StubOrgRepository<Store>(),
            memberRepository: StubOrgRepository<Member>(),
            saleRepository: saleRepository,
            developerTools: tools,
            preferences: UserDefaults(suiteName: "AppSessionTests-\(UUID().uuidString)")!
        )
    }

    @Test func ownerCanDoEverythingCashierIsLimited() async {
        let session = makeSession()
        await session.configure(user: makeSessionUser(role: .admin), platform: PlatformConfig())
        #expect(session.role == .owner)
        #expect(session.can(.admin))
        #expect(session.discountLimitPercent == 100)

        await session.configure(user: makeSessionUser(role: .standard), platform: PlatformConfig())
        #expect(session.role == .cashier)
        #expect(!session.can(.cancelBill))
        #expect(session.discountLimitPercent == 10)
        #expect(session.access(.cancelBill) != .allowed)
    }

    @Test func memberDocOverridesLegacyRole() async {
        let session = makeSession()
        session.seed(user: makeSessionUser(role: .standard), member: Member(id: "u1", name: "Kiran", role: .accountant))
        #expect(session.role == .accountant)
        #expect(session.can(.viewInsights))
        #expect(!session.can(.createBill))
    }

    @Test func flagsResolveThroughOrgAndDeveloperOverride() async {
        var settings = OrgSettings()
        settings.flags.org = [FeatureFlag.orders.rawValue: false]
        let tools = StubDeveloperTools()
        let session = makeSession(settings: settings, tools: tools)
        await session.configure(user: makeSessionUser(), platform: PlatformConfig())
        #expect(!session.isOn(.orders))
        tools.flagOverrides[FeatureFlag.orders.rawValue] = true
        #expect(session.isOn(.orders))
        #expect(session.resolution(of: .orders).source == .developer)
    }

    @Test func settingsDocDrivesShopNameAndVertical() async {
        var settings = OrgSettings()
        settings.profile.shopName = "Glitz Gifts & Fancy"
        settings.profile.vertical = .fancy
        let session = makeSession(settings: settings)
        await session.configure(user: makeSessionUser(), platform: PlatformConfig())
        #expect(session.hasSettingsDoc)
        #expect(session.displayShopName == "Glitz Gifts & Fancy")
        #expect(session.vertical == .fancy)
        #expect(session.currentStore.id == Store.defaultId)
    }

    @Test func freePlanCountsThisMonthsBillsAgainstTheLimit() async {
        var settings = OrgSettings()
        settings.plan = OrgSettings.Plan(tier: .free)
        let sales = (0..<3).map { index in
            Sale(id: "s\(index)", staffId: "u1", customerPhone: "", customerName: "", items: [], subtotal: 10,
                 overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 10, payments: [:],
                 timestamp: Date(), source: "POS", status: "Completed", whatsappStatus: "unsent")
        }
        let session = makeSession(settings: settings, sales: sales)
        await session.configure(user: makeSessionUser(), platform: PlatformConfig(freeBillLimit: 3, graceBills: 2))
        #expect(session.planStatus.billsUsed == 3)
        #expect(session.planStatus.isOverLimit)
        #expect(session.planStatus.graceLeft == 2)
    }

    @Test func saveSettingsPersistsAndUpdates() async throws {
        let session = makeSession()
        await session.configure(user: makeSessionUser(), platform: PlatformConfig())
        try await session.saveSettings { $0.tax.mode = .sameForAll; $0.tax.ratePercent = 5 }
        #expect(session.settings.tax.mode == .sameForAll)
        #expect(session.hasSettingsDoc)
    }
}

@MainActor
struct ThemeStoreTests {
    @Test func mapsAccentAndStyleToPalettes() {
        #expect(ThemeStore.maniTheme(for: .sage, style: .clean).name == "Kirana Sage")
        #expect(ThemeStore.maniTheme(for: .sage, style: .bold).name == "Fresh Teal")
        #expect(ThemeStore.maniTheme(for: .rose, style: .bold).name == "Rose")
    }

    @Test func userPreferencePersistsPerUser() async {
        let defaults = UserDefaults(suiteName: "ThemeStoreTests-\(UUID().uuidString)")!
        let store = ThemeStore(defaults: defaults)
        store.updatePreference({ $0.scheme = .dark; $0.accent = .plum; $0.useOrgTheme = false }, session: nil)
        #expect(store.resolved.accent == .plum)
        #expect(store.colorScheme == .dark)

        let reloaded = ThemeStore(defaults: defaults)
        reloaded.apply(session: nil)
        #expect(reloaded.preference.accent == .plum)
    }
}
