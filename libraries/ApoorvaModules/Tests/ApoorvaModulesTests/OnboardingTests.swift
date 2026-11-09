//
//  OnboardingTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaRepository
@testable import ApoorvaModules

final class RecordingAuthService: AuthServicing, @unchecked Sendable {
    var calls: [String] = []
    var account: AuthAccount? = AuthAccount(uid: "u1", email: "k@shop.in", isEmailVerified: false)
    var verifiedOnReload = false
    var currentUserStream: AsyncStream<AppUser?> { AsyncStream { $0.finish() } }
    var currentAccount: AuthAccount? { account }
    func login(email: String, password: String) async throws { calls.append("login:\(email)") }
    func logout() throws { calls.append("logout") }
    func register(name: String, email: String, password: String) async throws { calls.append("register:\(email)") }
    func sendEmailVerification() async throws { calls.append("verify") }
    func reloadAccount() async throws -> AuthAccount? {
        AuthAccount(uid: "u1", email: "k@shop.in", isEmailVerified: verifiedOnReload)
    }
    func sendPasswordReset(email: String) async throws { calls.append("reset:\(email)") }
}

final class RecordingSetupService: OrganizationSetupServicing, @unchecked Sendable {
    var createdShop: NewShop?
    var invite: Invite?
    var accepted: Invite?
    func createShop(_ shop: NewShop, owner: AuthAccount) async throws -> String { createdShop = shop; return "org-new" }
    func fetchInvite(token: String) async throws -> Invite? { invite }
    func createInvite(_ invite: Invite) throws { self.invite = invite }
    func acceptInvite(_ invite: Invite, account: AuthAccount, name: String, existingOrgs: [OrganizationSnapshot]) async throws {
        accepted = invite
    }
    func updateOrganizationStatus(orgId: String, status: String, reason: String) async throws {}
    func fetchAllOrganizations() async throws -> [Organization] { [] }
}

@MainActor
struct AuthFlowViewModelTests {
    @Test func registerRequiresNameEmailPasswordAndTerms() async {
        let auth = RecordingAuthService()
        let vm = AuthFlowViewModel(authService: auth)
        vm.name = "Kiran"
        vm.email = "k@shop.in"
        vm.password = "secret1"
        #expect(!vm.canRegister)
        vm.acceptedTerms = true
        #expect(vm.canRegister)
        #expect(await vm.register())
        #expect(auth.calls == ["register:k@shop.in"])
        #expect(vm.secondsUntilResend > 0)
    }

    @Test func passwordStrengthGuidesTheUser() {
        let vm = AuthFlowViewModel(authService: RecordingAuthService())
        vm.password = "abc"
        #expect(vm.passwordStrength.hasPrefix("Too short"))
        vm.password = "abcdefgh12"
        #expect(vm.passwordStrength == "Strong")
    }

    @Test func passwordResetNeedsAValidEmail() async {
        let auth = RecordingAuthService()
        let vm = AuthFlowViewModel(authService: auth)
        vm.email = "nope"
        #expect(!(await vm.sendPasswordReset()))
        vm.email = "k@shop.in"
        #expect(await vm.sendPasswordReset())
        #expect(auth.calls.contains("reset:k@shop.in"))
    }

    @Test func checkVerifiedReportsServerState() async {
        let auth = RecordingAuthService()
        let vm = AuthFlowViewModel(authService: auth)
        #expect(!(await vm.checkVerified()))
        #expect(vm.infoMessage != nil)
        auth.verifiedOnReload = true
        #expect(await vm.checkVerified())
    }

    @Test func phoneOTPExplainsItIsNotConfigured() async {
        let vm = AuthFlowViewModel(authService: RecordingAuthService())
        vm.phone = "98480 12345"
        #expect(await vm.sendOTP())
        vm.otp = "123456"
        #expect(!(await vm.verifyOTP()))
        #expect(vm.errorMessage != nil)
    }
}

@MainActor
struct ShopSetupViewModelTests {
    @Test func choosingAVerticalSetsItsAccent() {
        let vm = ShopSetupViewModel(authService: RecordingAuthService(), setupService: RecordingSetupService())
        vm.choose(.jewellery)
        #expect(vm.accent == .brass)
    }

    @Test func prefixFollowsShopNameInitials() {
        #expect(ShopSetupViewModel.suggestedPrefix(for: "Glitz Gifts & Fancy") == "GG-")
        #expect(ShopSetupViewModel.suggestedPrefix(for: "") == "A-")
    }

    @Test func finishCreatesTheShopWithChosenLook() async {
        let setup = RecordingSetupService()
        let vm = ShopSetupViewModel(authService: RecordingAuthService(), setupService: setup)
        vm.choose(.fancy)
        vm.shopName = "Glitz Gifts"
        vm.style = .bold
        #expect(await vm.finish())
        #expect(setup.createdShop?.vertical == .fancy)
        #expect(setup.createdShop?.theme.style == .bold)
        #expect(setup.createdShop?.shopName == "Glitz Gifts")
    }

    @Test func finishFailsWithoutAccount() async {
        let auth = RecordingAuthService()
        auth.account = nil
        let vm = ShopSetupViewModel(authService: auth, setupService: RecordingSetupService())
        #expect(!(await vm.finish()))
        #expect(vm.errorMessage != nil)
    }
}

@MainActor
struct StaffJoinViewModelTests {
    private func invite(expiresIn: TimeInterval = 3600, accepted: Bool = false) -> Invite {
        Invite(token: "ABCD2345", orgId: "org1", orgName: "Glitz", storeIds: ["default"], storeName: "Glitz Ameerpet",
               role: .cashier, name: "Anu", phone: "9000000000", invitedBy: "u0", invitedByName: "Kiran",
               createdAt: Date(), expiresAt: Date().addingTimeInterval(expiresIn),
               acceptedBy: accepted ? "other" : nil)
    }

    @Test func validInviteCanBeJoinedWhenSignedIn() async {
        let setup = RecordingSetupService()
        setup.invite = invite()
        let vm = StaffJoinViewModel(code: "abcd2345", setupService: setup, authService: RecordingAuthService())
        await vm.load()
        #expect(vm.name == "Anu")
        #expect(vm.canJoin)
        #expect(await vm.join())
        #expect(setup.accepted?.token == "ABCD2345")
    }

    @Test func expiredOrUsedInvitesCannotBeJoined() async {
        let setup = RecordingSetupService()
        setup.invite = invite(expiresIn: -10)
        let vm = StaffJoinViewModel(code: "ABCD2345", setupService: setup, authService: RecordingAuthService())
        await vm.load()
        #expect(!vm.canJoin)
        #expect(vm.errorMessage?.contains("expired") == true)

        setup.invite = invite(accepted: true)
        await vm.load()
        #expect(vm.errorMessage?.contains("already been used") == true)
    }

    @Test func missingInviteShowsAnError() async {
        let vm = StaffJoinViewModel(code: "ZZZZ9999", setupService: RecordingSetupService(), authService: RecordingAuthService())
        await vm.load()
        #expect(vm.invite == nil)
        #expect(vm.errorMessage != nil)
    }
}

@MainActor
struct PinSwitchViewModelTests {
    private func makeSUT() -> (PinSwitchViewModel, AppSession, InMemoryPinStore) {
        let session = AppSession(settingsRepository: StubOrgRepository<OrgSettings>(),
                                 storeRepository: StubOrgRepository<Store>(),
                                 memberRepository: StubOrgRepository<Member>(),
                                 saleRepository: StubSaleRepository(),
                                 developerTools: StubDeveloperTools(),
                                 preferences: UserDefaults(suiteName: "pin-\(UUID().uuidString)")!)
        session.seed(user: makeSessionUser(role: .admin))
        let pins = InMemoryPinStore()
        let anu = Member(id: "anu", name: "Anu", role: .cashier)
        let vm = PinSwitchViewModel(session: session,
                                    memberRepository: StubOrgRepository<Member>([anu]),
                                    pinStore: pins,
                                    biometrics: DeviceBiometrics())
        return (vm, session, pins)
    }

    @Test func correctPinSwitchesTheActingMember() async throws {
        let (vm, session, pins) = makeSUT()
        try pins.setPin("4821", for: "anu")
        await vm.load()
        vm.select(try #require(vm.members.first { $0.id == "anu" }))
        for digit in [4, 8, 2] { #expect(!vm.keyPressed(.digit(digit))) }
        #expect(vm.keyPressed(.digit(1)))
        #expect(session.actingMember?.id == "anu")
        #expect(session.role == .cashier)
    }

    @Test func wrongPinClearsAndShowsError() async throws {
        let (vm, session, pins) = makeSUT()
        try pins.setPin("4821", for: "anu")
        await vm.load()
        vm.select(try #require(vm.members.first { $0.id == "anu" }))
        for digit in [1, 1, 1, 1] { _ = vm.keyPressed(.digit(digit)) }
        #expect(vm.pin.isEmpty)
        #expect(vm.errorMessage != nil)
        #expect(session.actingMember == nil)
    }
}

@MainActor
struct OpeningBalancesViewModelTests {
    @Test func totalsAndCSVImport() async {
        let session = AppSession(settingsRepository: StubOrgRepository<OrgSettings>(),
                                 storeRepository: StubOrgRepository<Store>(),
                                 memberRepository: StubOrgRepository<Member>(),
                                 saleRepository: StubSaleRepository(),
                                 developerTools: StubDeveloperTools())
        let vm = OpeningBalancesViewModel(session: session,
                                          customerRepository: StubCustomerRepository(),
                                          ledgerRepository: StubOrgRepository<CustomerLedgerEntry>(),
                                          supplierRepository: StubOrgRepository<Supplier>(),
                                          dailyCashflowRepository: StubDailyCashflowRepository(),
                                          organizationRepository: StubOrganizationRepository())
        let added = vm.importCSV("name,phone,amount\nRavi,9848012345,500\nBad,123,abc\nMeena,9123456780,300")
        #expect(added == 2)
        vm.startDraft(supplier: true)
        vm.draftName = "Wholesale Co"
        vm.draftAmount = "1200"
        vm.addDraft()
        #expect(vm.customersOwe == 800)
        #expect(vm.youOwe == 1200)
    }

    @Test func saveWritesLedgerEntriesAndSuppliers() async {
        let session = AppSession(settingsRepository: StubOrgRepository<OrgSettings>(),
                                 storeRepository: StubOrgRepository<Store>(),
                                 memberRepository: StubOrgRepository<Member>(),
                                 saleRepository: StubSaleRepository(),
                                 developerTools: StubDeveloperTools())
        let ledger = StubOrgRepository<CustomerLedgerEntry>()
        let suppliers = StubOrgRepository<Supplier>()
        let customers = StubCustomerRepository()
        let vm = OpeningBalancesViewModel(session: session, customerRepository: customers, ledgerRepository: ledger,
                                          supplierRepository: suppliers, dailyCashflowRepository: StubDailyCashflowRepository(),
                                          organizationRepository: StubOrganizationRepository())
        _ = vm.importCSV("name,phone,amount\nRavi,9848012345,500")
        vm.startDraft(supplier: true)
        vm.draftName = "Wholesale Co"
        vm.draftAmount = "1200"
        vm.addDraft()
        #expect(await vm.save())
        #expect(ledger.documents.values.first?.kind == .opening)
        #expect(suppliers.documents.values.first?.openingDue == 1200)
        #expect(customers.customers.first?.dueBalance == 500)
    }
}

final class StubCustomerRepository: CustomerRepositoryProtocol, @unchecked Sendable {
    var customers: [Customer] = []
    func getCustomers() async throws -> [Customer] { customers }
    func saveCustomer(customer: Customer) async throws {
        customers.removeAll { $0.phone == customer.phone }
        customers.append(customer)
    }
    func updateCustomer(_ customer: Customer) async throws { try await saveCustomer(customer: customer) }
    func deleteCustomer(phoneNumber: String) async throws { customers.removeAll { $0.phone == phoneNumber } }
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws {}
}

final class StubDailyCashflowRepository: DailyCashflowSummaryRepositoryProtocol, @unchecked Sendable {
    var saved: [DailyCashflowSummary] = []
    func getDailyCashflowSummaries() async throws -> [DailyCashflowSummary] { saved }
    func getDailyCashflowSummary(id: String) async throws -> DailyCashflowSummary? { saved.first { $0.id == id } }
    func saveDailyCashflowSummary(summary: DailyCashflowSummary) async throws { saved.append(summary) }
    func updateDailyCashflowSummary(summary: DailyCashflowSummary) async throws {}
    func deleteDailyCashflowSummary(id: String) async throws {}
    func sync(force: Bool) async throws {}
    func refresh(for date: String) async throws {}
}

final class StubOrganizationRepository: OrganizationRepositoryProtocol, @unchecked Sendable {
    var organizations: [Organization] = []
    func getOrganizations() async throws -> [Organization] { organizations }
    func getOrganization(orgId: String) async throws -> Organization? { organizations.first { $0.id == orgId } }
    func saveOrganization(organization: Organization) async throws {}
    func sync(force: Bool) async throws {}
}
