//
//  SmallViewModelCoverageTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import SwiftUI
import ApoorvaModels
import ApoorvaRepository
import ApoorvaServices
import ApoorvaEnvironment
@testable import ApoorvaModules

private struct Failure: Error {}

/// Auth stub whose behaviour each test configures.
private final class ScriptedAuth: AuthServicing, @unchecked Sendable {
    var loginError: Error?
    var reloadError: Error?
    var logoutError: Error?
    var verifyError: Error?
    var account: AuthAccount?
    var logoutCount = 0
    var verifyCount = 0
    var loginCount = 0

    var currentUserStream: AsyncStream<AppUser?> { AsyncStream { $0.finish() } }
    var currentAccount: AuthAccount? { account }
    func login(email: String, password: String) async throws {
        loginCount += 1
        if let loginError { throw loginError }
    }
    func logout() throws {
        logoutCount += 1
        if let logoutError { throw logoutError }
    }
    func sendEmailVerification() async throws {
        verifyCount += 1
        if let verifyError { throw verifyError }
    }
    func reloadAccount() async throws -> AuthAccount? {
        if let reloadError { throw reloadError }
        return nil
    }
}

private final class FailingSetupService: OrganizationSetupServicing, @unchecked Sendable {
    func createShop(_ shop: NewShop, owner: AuthAccount) async throws -> String { throw Failure() }
    func fetchInvite(token: String) async throws -> Invite? { nil }
    func createInvite(_ invite: Invite) throws {}
    func acceptInvite(_ invite: Invite, account: AuthAccount, name: String, existingOrgs: [OrganizationSnapshot]) async throws {}
    func updateOrganizationStatus(orgId: String, status: String, reason: String) async throws {}
    func fetchAllOrganizations() async throws -> [Organization] { [] }
}

private final class Counter: @unchecked Sendable {
    var clears = 0
    var terminations = 0
}

// MARK: - LoginViewModel

@MainActor
struct LoginViewModelCoverageTests {
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<60 where !condition() { try await Task.sleep(nanoseconds: 50_000_000) }
    }

    @Test func successfulLoginLogsTheSignInMethod() async throws {
        let auth = ScriptedAuth()
        let vm = LoginViewModel(authService: auth, environment: .production)
        vm.username = " a@b.com "
        vm.password = "pw"
        vm.loginPressed()
        try await waitUntil { auth.loginCount == 1 && !vm.isLoggingIn }
        #expect(auth.loginCount == 1 && vm.errorMessage == nil)
    }

    @Test func accountExistingWithAnotherMethodAsksToLink() async throws {
        let auth = ScriptedAuth()
        auth.loginError = AuthServiceError.accountExistsWithDifferentCredential(email: "a@b.com")
        let vm = LoginViewModel(authService: auth, environment: .production)
        var linked: String?
        vm.onNeedsLinking = { linked = $0 }
        vm.username = "a@b.com"
        vm.password = "pw"
        vm.loginPressed()
        try await waitUntil { linked != nil }
        #expect(linked == "a@b.com")
        #expect(vm.errorMessage == nil)
    }
}

// MARK: - Profile / user lists

@MainActor
struct ProfileViewModelCoverageTests {
    private func makeSUT(repo: MockUserRepository = MockUserRepository()) -> ProfileViewModel {
        ProfileViewModel(userRepository: repo, authService: ScriptedAuth(), clearLocalData: {})
    }

    @Test func checkForUserLoadsTheCurrentUser() async throws {
        let repo = MockUserRepository()
        repo.currentUser = try makeModuleUser(orgId: "o1")
        let sut = makeSUT(repo: repo)
        await sut.checkForUser()
        #expect(sut.appUser?.id == "u1")
        #expect(sut.currentOrganization == "Org")
        #expect(sut.createdAt.count == 10 && sut.updatedAt.count == 10)
        #expect(sut.assignedOrganizations.isEmpty)
    }

    @Test func checkForUserSwallowsFailures() async {
        let repo = MockUserRepository()
        repo.shouldThrowOnLoad = true
        let sut = makeSUT(repo: repo)
        await sut.checkForUser()
        #expect(sut.appUser == nil)
    }

    @Test func derivedValuesWithoutAUser() {
        let sut = makeSUT()
        #expect(sut.currentOrganization == "Not assigned")
        #expect(sut.createdAt == "" && sut.updatedAt == "")
        #expect(sut.assignedOrganizations.isEmpty)
    }

    @Test func updatingTheSelectedOrganizationRefreshesTheUser() async throws {
        let repo = MockUserRepository()
        repo.currentUser = try makeModuleUser()
        let sut = makeSUT(repo: repo)
        await sut.updateSelectedOrganization(orgSnapshot: OrganizationSnapshot(orgId: "x", name: "X"))
        #expect(repo.updatedOrgs.isEmpty)

        await sut.checkForUser()
        await sut.updateSelectedOrganization(orgSnapshot: OrganizationSnapshot(orgId: "x", name: "X"))
        #expect(repo.updatedOrgs == ["x"])
        #expect(!sut.showAlert)

        repo.shouldThrowOnMutate = true
        await sut.updateSelectedOrganization(orgSnapshot: OrganizationSnapshot(orgId: "y", name: "Y"))
        #expect(sut.showAlert && !sut.alertMessage.isEmpty)
    }
}

@MainActor
struct ListViewModelFailureTests {
    @Test func organizationListReportsFailures() async {
        let repo = MockUserRepository()
        repo.shouldThrowOnLoad = true
        let sut = OrganizationListViewModel(userRepository: repo)
        await sut.load()
        #expect(sut.errorMessage == "Unable to load organizations.")
        #expect(!sut.isLoading)
    }

    @Test func userListReportsFailuresAndMissingOrganizations() async throws {
        let repo = MockUserRepository()
        repo.shouldThrowOnLoad = true
        let sut = UserListViewModel(userRepository: repo)
        await sut.load()
        #expect(sut.errorMessage == "Unable to load team members.")

        repo.shouldThrowOnLoad = false
        repo.currentUser = try makeModuleUser()
        await sut.load()
        #expect(sut.users.isEmpty && sut.errorMessage == nil)
    }
}

// MARK: - DeveloperSettingsViewModel

@MainActor
struct DeveloperSettingsViewModelCoverageTests {
    private func makeSUT(active: AppEnvironment, auth: ScriptedAuth = ScriptedAuth(), counter: Counter = Counter()) -> DeveloperSettingsViewModel {
        let defaults = UserDefaults(suiteName: "DevCoverage-\(UUID().uuidString)")!
        defaults.set(active.rawValue, forKey: "apoorva.selectedEnvironment")
        return DeveloperSettingsViewModel(authService: auth, environmentStore: EnvironmentStore(defaults: defaults),
                                          tools: StubDeveloperTools(),
                                          clearLocalDatabase: { counter.clears += 1 },
                                          terminateApp: { counter.terminations += 1 })
    }

    @Test func destructiveToolsFollowTheActiveEnvironment() {
        let counter = Counter()
        let debug = makeSUT(active: .debug, counter: counter)
        #expect(debug.canClearDatabase == AppEnvironment.debug.allowsDestructiveTools)
        debug.clearLocalDatabase()
        #expect(counter.clears == (AppEnvironment.debug.allowsDestructiveTools ? 1 : 0))

        let production = makeSUT(active: .production, counter: counter)
        let before = counter.clears
        production.clearLocalDatabase()
        #expect(counter.clears == before + (AppEnvironment.production.allowsDestructiveTools ? 1 : 0))
    }

    @Test func switchingDoesNothingUntilADifferentEnvironmentIsPicked() {
        let auth = ScriptedAuth()
        let counter = Counter()
        let sut = makeSUT(active: .debug, auth: auth, counter: counter)
        sut.confirmEnvironmentSwitch()
        #expect(auth.logoutCount == 0 && counter.terminations == 0)
    }

    @Test func switchingSignsOutClearsAndTerminates() {
        for active in AppEnvironment.allCases {
            let auth = ScriptedAuth()
            let counter = Counter()
            let sut = makeSUT(active: active, auth: auth, counter: counter)
            sut.pendingEnvironment = AppEnvironment.allCases.first { $0 != active }!
            #expect(sut.canSwitchEnvironment)
            sut.confirmEnvironmentSwitch()
            #expect(auth.logoutCount == 1 && counter.terminations == 1)
            #expect(counter.clears == (active.allowsDestructiveTools ? 1 : 0))
        }
    }

    @Test func switchingReportsSignOutFailures() {
        let auth = ScriptedAuth()
        auth.logoutError = Failure()
        let counter = Counter()
        let sut = makeSUT(active: .debug, auth: auth, counter: counter)
        sut.pendingEnvironment = .production
        sut.confirmEnvironmentSwitch()
        #expect(sut.errorMessage != nil && counter.terminations == 0)
    }
}

// MARK: - AuthFlowViewModel

@MainActor
struct AuthFlowViewModelCoverageTests {
    @Test func resendVerificationHonoursTheCooldown() async {
        let auth = ScriptedAuth()
        let sut = AuthFlowViewModel(authService: auth)
        await sut.resendVerification()
        #expect(auth.verifyCount == 1 && sut.infoMessage == "We sent a new link.")
        await sut.resendVerification()
        #expect(auth.verifyCount == 1)
    }

    @Test func resendVerificationReportsFailures() async {
        let auth = ScriptedAuth()
        auth.verifyError = Failure()
        let sut = AuthFlowViewModel(authService: auth)
        await sut.resendVerification()
        #expect(sut.errorMessage != nil)
    }

    @Test func checkVerifiedHandlesMissingAccountsAndFailures() async {
        let auth = ScriptedAuth()
        let sut = AuthFlowViewModel(authService: auth)
        #expect(await sut.checkVerified() == false)
        #expect(sut.infoMessage?.hasPrefix("Not verified") == true)

        auth.reloadError = Failure()
        #expect(await sut.checkVerified() == false)
        #expect(sut.errorMessage != nil)
    }

    @Test func signInToLinkNeedsAPassword() async {
        let auth = ScriptedAuth()
        let sut = AuthFlowViewModel(authService: auth)
        sut.email = "a@b.com"
        #expect(await sut.signInToLink() == false)
        sut.password = "secret1"
        #expect(await sut.signInToLink())
        #expect(auth.loginCount == 1)
        auth.loginError = Failure()
        #expect(await sut.signInToLink() == false)
    }

    @Test func sendOTPValidatesThePhoneNumber() async {
        let sut = AuthFlowViewModel(authService: ScriptedAuth())
        sut.phone = "123"
        #expect(await sut.sendOTP() == false)
        #expect(sut.errorMessage == "Enter a 10-digit phone number.")
        sut.phone = "98480 12345"
        #expect(await sut.sendOTP())
        #expect(sut.secondsUntilResend > 0)
    }
}

// MARK: - ShopSetupViewModel

@MainActor
struct ShopSetupViewModelCoverageTests {
    @Test func customPrefixesAreKeptWhenChoosingAVertical() {
        let sut = ShopSetupViewModel(authService: ScriptedAuth(), setupService: RecordingSetupService())
        sut.billPrefix = "X-"
        sut.shopName = "Glitz Gifts"
        sut.choose(.fancy)
        #expect(sut.billPrefix == "X-")
        sut.billPrefix = ""
        sut.choose(.fancy)
        #expect(sut.billPrefix == "GG-")
    }

    @Test func continueNeedsAShopNameAndPrefixFollowsIt() {
        let sut = ShopSetupViewModel(authService: ScriptedAuth(), setupService: RecordingSetupService())
        #expect(!sut.canContinueShop)
        sut.shopName = "  Ramesh Store "
        #expect(sut.canContinueShop)
        sut.shopNameChanged()
        #expect(sut.billPrefix == "RS-")
    }

    @Test func ownerNameFallsBackToTheEmailOrOwner() async {
        let setup = RecordingSetupService()
        let auth = ScriptedAuth()
        auth.account = AuthAccount(uid: "u", email: "kiran@shop.in", isEmailVerified: true)
        let sut = ShopSetupViewModel(authService: auth, setupService: setup)
        sut.shopName = "S"
        sut.billPrefix = ""
        #expect(await sut.finish())
        #expect(setup.createdShop?.ownerName == "kiran")
        #expect(setup.createdShop?.billPrefix == "A-")

        auth.account = AuthAccount(uid: "u", email: nil, isEmailVerified: true)
        #expect(await sut.finish())
        #expect(setup.createdShop?.ownerName == "Owner")
    }

    @Test func creationFailureIsReported() async {
        let auth = ScriptedAuth()
        auth.account = AuthAccount(uid: "u", email: "a@b.com", isEmailVerified: true)
        let sut = ShopSetupViewModel(authService: auth, setupService: FailingSetupService())
        #expect(await sut.finish() == false)
        #expect(sut.errorMessage?.hasPrefix("Couldn't create your shop") == true)
        #expect(!sut.isCreating)
    }
}

// MARK: - QuickAddLineViewModel

@MainActor
struct QuickAddLineViewModelCoverageTests {
    private func line(type: DiscountType, discountPercent: Double = 10, mrp: Double = 100, quantity: Int = 2) -> CartItem {
        var item = CartItem(category: InventoryItem(id: "i", name: "Chain"), mrp: mrp, discountPercent: discountPercent, quantity: quantity)
        item.discountType = type
        return item
    }

    @Test func discountModesHaveLabels() {
        #expect(QuickDiscountMode.finalPrice.fieldLabel == "Final price per unit")
        #expect(QuickDiscountMode.percent.fieldLabel == "Discount %")
        #expect(QuickDiscountMode.amount.fieldLabel == "Discount per unit")
    }

    @Test func existingLinesReopenInTheirOwnMode() {
        let final = QuickAddLineViewModel(line: line(type: .finalPrice), isNew: false)
        #expect(final.mode == .finalPrice && final.valueText == "90")
        let amount = QuickAddLineViewModel(line: line(type: .amount), isNew: false)
        #expect(amount.mode == .amount && amount.valueText == "10")
        let percent = QuickAddLineViewModel(line: line(type: .percentage), isNew: false)
        #expect(percent.mode == .percent && percent.valueText == "10")
    }

    @Test func linesWithoutADiscountStartEmpty() {
        let finalNoDiscount = QuickAddLineViewModel(line: line(type: .finalPrice, discountPercent: 0), isNew: false)
        #expect(finalNoDiscount.valueText == "")
        let amountNoDiscount = QuickAddLineViewModel(line: line(type: .amount, discountPercent: 0), isNew: false)
        #expect(amountNoDiscount.valueText == "")
        let existingPercent = QuickAddLineViewModel(line: line(type: .percentage, discountPercent: 0), isNew: false)
        #expect(existingPercent.mode == .percent && existingPercent.valueText == "")
        let noMrp = QuickAddLineViewModel(line: line(type: .percentage, mrp: 0), isNew: true)
        #expect(noMrp.mrpText == "" && noMrp.mode == .finalPrice)
    }

    @Test func validityAndQuantityStepping() {
        let sut = QuickAddLineViewModel(line: line(type: .percentage), isNew: false)
        #expect(sut.isValid)
        sut.decrement()
        sut.decrement()
        sut.decrement()
        #expect(sut.quantity == 1)
        sut.mrpText = ""
        #expect(!sut.isValid)
    }
}

// MARK: - ThemeStore

@MainActor
struct ThemeStoreCoverageTests {
    private func makeStore() -> ThemeStore {
        ThemeStore(defaults: UserDefaults(suiteName: "ThemeCoverage-\(UUID().uuidString)")!)
    }

    @Test func everyAccentAndStyleHasAPalette() {
        for accent in AccentKey.allCases {
            for style in [OrgSettings.VisualStyle.clean, .bold] {
                #expect(!ThemeStore.maniTheme(for: accent, style: style).name.isEmpty)
            }
            _ = ThemeStore.swatchColor(for: accent)
        }
    }

    @Test func previewReplacesTheLookWithoutSaving() {
        let store = makeStore()
        store.preview(accent: .plum, style: .bold, scheme: .dark)
        #expect(store.resolved.accent == .plum && store.style == .bold && store.colorScheme == .dark)
        store.preview(accent: .ink, style: .clean, scheme: .light)
        #expect(store.style == .clean && store.colorScheme == .light)
    }

    @Test func applyingASessionResolvesFromOrgSettingsAndStores() {
        let store = makeStore()
        var settings = OrgSettings()
        settings.theme = OrgSettings.Theme(accent: .brass, style: .bold)
        let session = makeSeededSession(settings: settings)
        session.seed(stores: [Store.defaultStore(name: "S", vertical: .kirana, billPrefix: "S-")])
        store.apply(session: session)
        #expect(store.resolved.accent == .brass)
        store.apply(session: nil)
        store.apply(session: session)
    }

    @Test func themeModifierBuildsAView() {
        _ = Text("Hello").maniTheme(from: makeStore())
    }
}
