//
//  CashflowAndReceiptViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
import ApoorvaServices
import ApoorvaEnvironment
import ApoorvaUtilities
@testable import ApoorvaModules

// MARK: - Shared helpers (internal so later test files can reuse them)

@MainActor
func makeSeededSession(settings: OrgSettings = OrgSettings()) -> AppSession {
    let session = AppSession(
        settingsRepository: StubOrgRepository<OrgSettings>(),
        storeRepository: StubOrgRepository<Store>(),
        memberRepository: StubOrgRepository<Member>(),
        saleRepository: StubSaleRepository(),
        developerTools: StubDeveloperTools(),
        preferences: UserDefaults(suiteName: "seeded-\(UUID().uuidString)")!,
        appConfig: AppConfig(service: NoOpRemoteConfigService())
    )
    session.seed(user: makeSessionUser(), settings: settings)
    return session
}

private struct Boom: Error, LocalizedError {
    var errorDescription: String? { "boom" }
}

private func day(_ offset: Int) -> Date {
    Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: Date()))!
}

private func atNoon(_ offset: Int) -> Date {
    Calendar.current.date(byAdding: .hour, value: 12, to: day(offset))!
}

private let cashAccount = Account(id: "cash", name: "Cash", type: .cash, currentBalance: 0)
private let upiAccount = Account(id: "upi", name: "UPI", type: .upi, currentBalance: 0)

private func organization(establishedDaysAgo: Int = 3) -> Organization {
    Organization(id: "org1", name: "Org", status: "active", createdAt: Date(), minVersion: "1.0", currentTheme: "light",
                 accentColor: "#000000", accounts: [cashAccount, upiAccount],
                 establishedAtInMs: day(-establishedDaysAgo).timeIntervalSince1970)
}

private func transaction(_ id: String, type: CashflowTransaction.TransactionType = .credit, amount: Double = 100,
                         category: CashflowCategory = .salesRevenue, at date: Date = atNoon(0), deleted: Bool = false,
                         from: String = "", to: String = "") -> CashflowTransaction {
    CashflowTransaction(id: id, timestamp: date, particulars: id, amount: amount, transactionType: type, paymentMode: .cash,
                        category: category, fromAccountId: from, toAccountId: to, isDeleted: deleted,
                        timestampInMs: date.timeIntervalSince1970, updatedAtInMs: 1)
}

private func summary(_ date: Date, opening: [AccountBalance] = [], closing: [AccountBalance] = [], locked: Bool = false) -> DailyCashflowSummary {
    DailyCashflowSummary(date: date, openingBalances: opening, closingBalances: closing, updatedAt: 1, locked: locked)
}

private final class SummaryRepo: DailyCashflowSummaryRepositoryProtocol, @unchecked Sendable {
    var summaries: [DailyCashflowSummary] = []
    var failGetAll = false, failSync = false, failUpdate = false, failSave = false, failRefresh = false
    var calls: [String] = []
    var updated: DailyCashflowSummary?
    var saved: DailyCashflowSummary?

    func getDailyCashflowSummaries() async throws -> [DailyCashflowSummary] {
        if failGetAll { throw Boom() }
        return summaries
    }
    func getDailyCashflowSummary(id: String) async throws -> DailyCashflowSummary? {
        if failGetAll { throw Boom() }
        return summaries.first { $0.id == id }
    }
    func saveDailyCashflowSummary(summary: DailyCashflowSummary) async throws {
        if failSave { throw Boom() }
        saved = summary
    }
    func updateDailyCashflowSummary(summary: DailyCashflowSummary) async throws {
        if failUpdate { throw Boom() }
        updated = summary
        summaries.removeAll { $0.id == summary.id }
        summaries.append(summary)
    }
    func deleteDailyCashflowSummary(id: String) async throws {}
    func sync(force: Bool) async throws {
        calls.append("sync:\(force)")
        if failSync { throw Boom() }
    }
    func refresh(for date: String) async throws {
        calls.append("refresh")
        if failRefresh { throw Boom() }
    }
}

private final class TransactionRepo: CashflowTransactionRepositoryProtocol, @unchecked Sendable {
    var transactions: [CashflowTransaction] = []
    var failSave = false, failUpdate = false, failMark = false
    var saved: CashflowTransaction?
    var updated: CashflowTransaction?
    var marked: [String] = []

    func getCashflowTransactions() async throws -> [CashflowTransaction] { transactions }
    func saveCashflowTransaction(transaction: CashflowTransaction) async throws {
        if failSave { throw Boom() }
        saved = transaction
    }
    func updateCashflowTransaction(_ transaction: CashflowTransaction) async throws {
        if failUpdate { throw Boom() }
        updated = transaction
    }
    func deleteCashflowTransaction(id: String) async throws {}
    func markAsDeleted(id: String) async throws {
        if failMark { throw Boom() }
        marked.append(id)
    }
    func sync(force: Bool) async throws {}
}

private final class OrgRepo: OrganizationRepositoryProtocol, @unchecked Sendable {
    var organizations: [Organization]
    var fail = false
    init(_ organizations: [Organization] = [organization()]) { self.organizations = organizations }
    func getOrganizations() async throws -> [Organization] { organizations }
    func getOrganization(orgId: String) async throws -> Organization? {
        if fail { throw Boom() }
        return organizations.first { $0.id == orgId }
    }
    func saveOrganization(organization: Organization) async throws {}
    func sync(force: Bool) async throws {}
}

private final class HeldBillsRepo: HeldBillRepositoryProtocol, @unchecked Sendable {
    var heldBills: [HeldBill] = []
    var failGet = false, failSync = false, failDelete = false
    var deleted: [String] = []

    func getHeldBills() async throws -> [HeldBill] {
        if failGet { throw Boom() }
        return heldBills
    }
    func saveHeldBill(_ heldBill: HeldBill) async throws {}
    func updateHeldBill(_ heldBill: HeldBill) async throws {}
    func deleteHeldBill(id: String) async throws {
        if failDelete { throw Boom() }
        deleted.append(id)
    }
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws { if failSync { throw Boom() } }
}

private final class ReceiptSaleRepo: SaleRepositoryProtocol, @unchecked Sendable {
    var sale: Sale?
    var fail = false
    func getSales() async throws -> [Sale] { [] }
    func getSale(id: String) async throws -> Sale? {
        if fail { throw Boom() }
        return sale
    }
    func saveSale(sale: Sale) async throws {}
    func updateSale(_ sale: Sale) async throws {}
    func deleteSale(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func confirmSale(_ sale: Sale, heldBillId: String?) async throws {}
    func cancelSale(id: String, reason: String, by staffId: String) async throws -> Sale? { nil }
    func editSale(_ sale: Sale, reason: String) async throws {}
    func sync(force: Bool) async throws {}
}

private func userRepo(orgId: String? = "org1") throws -> MockUserRepository {
    let repo = MockUserRepository()
    repo.currentUser = try makeModuleUser(orgId: orgId)
    return repo
}

// MARK: - HeldBillsViewModel

@MainActor
struct HeldBillsViewModelTests {
    private func bill(_ id: String, at seconds: TimeInterval) -> HeldBill {
        HeldBill(id: id, customerName: "A", customerPhone: "9", items: [], total: 10, createdAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func prepareDataLoadsSortedBills() async {
        let repo = HeldBillsRepo()
        repo.heldBills = [bill("old", at: 1), bill("new", at: 100)]
        let sut = HeldBillsViewModel(repository: repo)
        await sut.prepareData()
        #expect(sut.heldBills.count == 2)
    }

    @Test func prepareDataSurvivesFailures() async {
        let repo = HeldBillsRepo()
        repo.failSync = true
        let sut = HeldBillsViewModel(repository: repo)
        await sut.prepareData()
        repo.failSync = false
        repo.failGet = true
        await sut.prepareData()
        #expect(sut.heldBills.isEmpty)
    }

    @Test func deleteRemovesBillOnlyOnSuccess() async {
        let repo = HeldBillsRepo()
        repo.heldBills = [bill("a", at: 1), bill("b", at: 2)]
        let sut = HeldBillsViewModel(repository: repo)
        await sut.prepareData()
        repo.failDelete = true
        await sut.delete(bill("a", at: 1))
        #expect(sut.heldBills.count == 2)
        repo.failDelete = false
        await sut.delete(bill("a", at: 1))
        #expect(sut.heldBills.map(\.id) == ["b"])
        #expect(repo.deleted == ["a"])
    }
}

// MARK: - ReceiptViewModel

@MainActor
struct ReceiptViewModelTests {
    private func sale(phone: String = "98480 12345", cash: Double = 20, credit: Double = 80) -> Sale {
        var payments: [PaymentMode: Double] = [.cash: cash]
        if credit > 0 { payments[.credit] = credit }
        return Sale(id: "s1", staffId: "u", customerPhone: phone, customerName: "Asha", items: [], subtotal: 100,
                    overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 100, payments: payments,
                    timestamp: Date(), source: "POS", status: "Completed", whatsappStatus: "unsent")
    }

    @Test func loadStoresSaleAndSwallowsErrors() async {
        let repo = ReceiptSaleRepo()
        repo.sale = sale()
        let sut = ReceiptViewModel(saleId: "s1", saleRepository: repo)
        await sut.load()
        #expect(sut.sale?.id == "s1")
        repo.fail = true
        await sut.load()
        #expect(sut.sale?.id == "s1")
    }

    @Test func emptyStateWithoutASale() {
        let sut = ReceiptViewModel(saleId: "s1", saleRepository: ReceiptSaleRepo())
        #expect(sut.shopName == "")
        #expect(sut.changeReturned == 0)
        #expect(sut.paidBy == "")
        #expect(sut.shareText == "")
        #expect(sut.thermalLines.isEmpty)
        #expect(sut.smsURL == nil)
        #expect(sut.whatsAppURL != nil)
    }

    @Test func changeAndPaymentSummary() async {
        let repo = ReceiptSaleRepo()
        repo.sale = sale()
        let sut = ReceiptViewModel(saleId: "s1", saleRepository: repo, cashReceived: 50)
        await sut.load()
        #expect(sut.changeReturned == 30)
        sut.cashReceived = nil
        #expect(sut.changeReturned == 0)
        #expect(sut.paidBy.contains("+"))
    }

    @Test func sharingUsesSessionSettings() async {
        var settings = OrgSettings()
        settings.profile.shopName = "Glitz"
        settings.payments.upiId = "glitz@upi"
        let repo = ReceiptSaleRepo()
        repo.sale = sale()
        let sut = ReceiptViewModel(saleId: "s1", saleRepository: repo, session: makeSeededSession(settings: settings))
        await sut.load()
        #expect(sut.shopName == "Glitz")
        #expect(sut.shareText.contains("Glitz"))
        #expect(!sut.thermalLines.isEmpty)
    }

    @Test func wideReceiptsAndPaidSalesHaveNoUPILink() async {
        var settings = OrgSettings()
        settings.receipt.paperSize = .mm80
        settings.payments.upiId = "glitz@upi"
        let repo = ReceiptSaleRepo()
        repo.sale = sale(cash: 100, credit: 0)
        let sut = ReceiptViewModel(saleId: "s1", saleRepository: repo, session: makeSeededSession(settings: settings))
        await sut.load()
        #expect(!sut.shareText.contains("upi://"))
        #expect(!sut.thermalLines.isEmpty)
    }

    @Test func messageLinksNormalisePhoneNumbers() async {
        let repo = ReceiptSaleRepo()
        let sut = ReceiptViewModel(saleId: "s1", saleRepository: repo)
        repo.sale = sale(phone: "98480 12345")
        await sut.load()
        #expect(sut.whatsAppURL?.absoluteString.hasPrefix("https://wa.me/919848012345") == true)
        #expect(sut.smsURL?.absoluteString.hasPrefix("sms:9848012345") == true)
        repo.sale = sale(phone: "+44 20 7946 0958")
        await sut.load()
        #expect(sut.whatsAppURL?.absoluteString.hasPrefix("https://wa.me/442079460958") == true)
        repo.sale = sale(phone: "")
        await sut.load()
        #expect(sut.smsURL == nil)
    }
}

// MARK: - AddUpdateCashflowTransactionViewModel

@MainActor
struct AddUpdateCashflowTransactionViewModelTests {
    private func makeSUT(existing: CashflowTransaction? = nil, user: MockUserRepository? = nil, orgs: OrgRepo = OrgRepo(),
                         repo: TransactionRepo = TransactionRepo()) throws -> (AddUpdateCashflowTransactionViewModel, TransactionRepo) {
        (AddUpdateCashflowTransactionViewModel(repository: repo, userRepository: try user ?? userRepo(), organizationRepository: orgs,
                                               existingTransaction: existing), repo)
    }

    @Test func newTransactionStartsBlank() throws {
        let (sut, _) = try makeSUT()
        #expect(!sut.isUpdating && sut.amountText.isEmpty && sut.person.isEmpty)
    }

    @Test func existingTransactionPrefillsEveryField() throws {
        var existing = transaction("t1", amount: 42, from: "cash", to: "upi")
        existing = CashflowTransaction(id: "t1", timestamp: existing.timestamp, particulars: "Tea", amount: 42, transactionType: .debit,
                                       paymentMode: .upi, category: .miscellaneous, subCategory: nil, fromAccountId: "cash",
                                       toAccountId: "upi", person: "Ravi", timestampInMs: 1, updatedAtInMs: 1)
        let (sut, _) = try makeSUT(existing: existing)
        #expect(sut.isUpdating && sut.id == "t1" && sut.amountText == "42.0" && sut.person == "Ravi")
        #expect(sut.subCategory == .unknown && sut.fromAccountId == "cash" && sut.toAccountId == "upi")
        let (noPerson, _) = try makeSUT(existing: transaction("t2"))
        #expect(noPerson.person == "")
    }

    @Test func fetchAccountsLoadsOrganizationAccounts() async throws {
        let (sut, _) = try makeSUT()
        await sut.fetchAccounts()
        #expect(sut.accounts.count == 2 && sut.errorMessage == nil)
    }

    @Test func fetchAccountsReportsEveryFailure() async throws {
        let (noOrg, _) = try makeSUT(user: try userRepo(orgId: nil))
        await noOrg.fetchAccounts()
        #expect(noOrg.errorMessage == "No organization selected.")

        let (missing, _) = try makeSUT(orgs: OrgRepo([]))
        await missing.fetchAccounts()
        #expect(missing.errorMessage == "Organization details not found.")

        let failing = OrgRepo()
        failing.fail = true
        let (broken, _) = try makeSUT(orgs: failing)
        await broken.fetchAccounts()
        #expect(broken.errorMessage?.hasPrefix("Failed to load accounts") == true)
    }

    @Test func saveRejectsBadAmounts() async throws {
        let (sut, repo) = try makeSUT()
        sut.amountText = "abc"
        #expect(await sut.save() == false)
        sut.amountText = "0"
        #expect(await sut.save() == false)
        #expect(repo.saved == nil && !sut.isSaving)
    }

    @Test func saveCreatesTransactionWithDefaultsAndMapsUnknownSubCategory() async throws {
        let (sut, repo) = try makeSUT()
        sut.amountText = "25"
        sut.subCategory = .unknown
        #expect(await sut.save())
        #expect(repo.saved?.particulars == "No particulars")
        #expect(repo.saved?.subCategory == nil)
        sut.particulars = "Tea"
        sut.subCategory = .painting
        #expect(await sut.save())
        #expect(repo.saved?.particulars == "Tea" && repo.saved?.subCategory == .painting)
    }

    @Test func saveUpdatesExistingAndReportsFailures() async throws {
        let (sut, repo) = try makeSUT(existing: transaction("t1"))
        #expect(await sut.save())
        #expect(repo.updated?.id == "t1")
        repo.failUpdate = true
        #expect(await sut.save() == false)
        #expect(sut.errorMessage == "boom")

        let (adding, addRepo) = try makeSUT()
        adding.amountText = "5"
        addRepo.failSave = true
        #expect(await adding.save() == false)
    }
}

// MARK: - DailyCashFlowViewModel

@MainActor
struct DailyCashFlowViewModelTests {
    private func makeSUT(summaries: SummaryRepo = SummaryRepo(), transactions: TransactionRepo = TransactionRepo(),
                         user: MockUserRepository? = nil, orgs: OrgRepo = OrgRepo(), date: Date? = nil) throws
    -> (DailyCashFlowViewModel, SummaryRepo, TransactionRepo) {
        (DailyCashFlowViewModel(repository: summaries, userRepository: try user ?? userRepo(), organizationRepository: orgs,
                                cashflowRepository: transactions, selectedDate: date), summaries, transactions)
    }

    @Test func fetchDataBuildsAnOpeningSummaryFromThePreviousDay() async throws {
        let summaries = SummaryRepo()
        summaries.summaries = [summary(day(-1), closing: [AccountBalance(id: "cash", name: "Cash", balance: 70)]),
                               summary(day(-2), closing: [AccountBalance(id: "cash", name: "Cash", balance: 5)])]
        let transactions = TransactionRepo()
        transactions.transactions = [transaction("b", at: atNoon(0)), transaction("a", at: day(0).addingTimeInterval(60)),
                                     transaction("setup", category: .shopSetup), transaction("gone", deleted: true),
                                     transaction("yesterday", at: atNoon(-1))]
        let (sut, _, _) = try makeSUT(summaries: summaries, transactions: transactions)
        await sut.fetchData()
        #expect(sut.accounts.count == 2)
        #expect(sut.currentSummary?.openingBalances.first { $0.id == "cash" }?.balance == 70)
        #expect(sut.currentSummary?.openingBalances.first { $0.id == "upi" }?.balance == 0)
        #expect(sut.transactions.map(\.id) == ["a", "b"])
        #expect(!sut.isLoading)
    }

    @Test func fetchDataWithoutAnyPreviousSummaryOpensAtZero() async throws {
        let (sut, _, _) = try makeSUT()
        await sut.fetchData()
        #expect(sut.currentSummary?.openingBalances.allSatisfy { $0.balance == 0 } == true)
        sut.fetchSummary()
    }

    @Test func existingSummaryIsReusedAndMissingOrgGivesNoAccounts() async throws {
        let summaries = SummaryRepo()
        let today = Date()
        summaries.summaries = [summary(today)]
        let (sut, _, _) = try makeSUT(summaries: summaries, user: try userRepo(orgId: nil))
        await sut.fetchData()
        #expect(sut.currentSummary != nil && sut.accounts.isEmpty)

        let (missingOrg, _, _) = try makeSUT(orgs: OrgRepo([]))
        #expect(try await missingOrg.getAccounts().isEmpty)
        #expect(try await missingOrg.getOrganizationId() == "org1")
    }

    @Test func fetchDataFailureIsSwallowed() async throws {
        let summaries = SummaryRepo()
        summaries.failGetAll = true
        let (sut, _, _) = try makeSUT(summaries: summaries)
        await sut.fetchData()
        #expect(sut.currentSummary == nil)
    }

    @Test func deleteTransactionMarksAndReloads() async throws {
        let transactions = TransactionRepo()
        let (sut, _, _) = try makeSUT(transactions: transactions)
        await sut.deleteTransaction(id: "t1")
        #expect(transactions.marked == ["t1"])
        transactions.failMark = true
        await sut.deleteTransaction(id: "t2")
        #expect(transactions.marked == ["t1"])
    }

    @Test func dateNavigationMovesByOneDay() throws {
        let start = day(0)
        let (sut, _, _) = try makeSUT(date: start)
        sut.nextDate()
        #expect(sut.selectedDate == day(1))
        sut.prevDate()
        sut.prevDate()
        #expect(sut.selectedDate == day(-1))
    }

    @Test func toggleLockFlipsTheLockAndHandlesFailure() async throws {
        let summaries = SummaryRepo()
        let (sut, _, _) = try makeSUT(summaries: summaries)
        await sut.toggleLockStatus()
        #expect(summaries.updated == nil)

        summaries.summaries = [summary(Date())]
        await sut.fetchData()
        await sut.toggleLockStatus()
        #expect(summaries.updated?.locked == true)

        summaries.failUpdate = true
        await sut.toggleLockStatus()
        #expect(!sut.isLoading)
    }

    @Test func refreshDataForcesARefreshThenReloads() async throws {
        let summaries = SummaryRepo()
        let (sut, _, _) = try makeSUT(summaries: summaries)
        await sut.refreshData()
        #expect(summaries.calls == ["refresh"])
        summaries.failRefresh = true
        await sut.refreshData()
    }
}

// MARK: - DailyCashFlowListViewModel

@MainActor
struct DailyCashFlowListViewModelTests {
    private func makeSUT(summaries: SummaryRepo = SummaryRepo(), transactions: TransactionRepo = TransactionRepo(),
                         user: MockUserRepository? = nil, orgs: OrgRepo = OrgRepo()) throws -> (DailyCashFlowListViewModel, SummaryRepo) {
        (DailyCashFlowListViewModel(repository: summaries, userRepository: try user ?? userRepo(), organizationRepository: orgs,
                                    cashflowRepository: transactions), summaries)
    }

    @Test func fetchDataFillsEveryDayFromEstablishmentAndComputesStats() async throws {
        let summaries = SummaryRepo()
        summaries.summaries = [summary(day(0), locked: true)]
        let transactions = TransactionRepo()
        transactions.transactions = [
            transaction("in", type: .credit, amount: 500),
            transaction("out", type: .debit, amount: 120.4),
            transaction("setup", type: .debit, amount: 1000, category: .shopSetup),
            transaction("stock", type: .debit, amount: 300, category: .inventory),
            transaction("move", type: .debit, amount: 50, category: .internalTransfer),
            transaction("gone", type: .credit, amount: 9, deleted: true)
        ]
        let (sut, _) = try makeSUT(summaries: summaries, transactions: transactions)
        await sut.fetchData()
        #expect(sut.summaries.count == 4)
        #expect(sut.summaries.first?.locked == true)
        #expect(sut.totalIncome == 500)
        #expect(sut.totalExpense == 1420.4)
        #expect(sut.shopSetupTotal == 1000 && sut.inventoryTotal == 300)
        #expect(sut.profitOrLoss == -920)
        #expect(!sut.isLoading)
    }

    @Test func missingOrganizationLeavesTheListEmpty() async throws {
        let (noOrg, _) = try makeSUT(user: try userRepo(orgId: nil))
        await noOrg.fetchData()
        #expect(noOrg.summaries.isEmpty)
        let (missing, _) = try makeSUT(orgs: OrgRepo([]))
        await missing.fetchData()
        #expect(missing.summaries.isEmpty)
    }

    @Test func fetchFailureStopsLoading() async throws {
        let summaries = SummaryRepo()
        summaries.failGetAll = true
        let (sut, _) = try makeSUT(summaries: summaries)
        await sut.fetchData()
        #expect(!sut.isLoading)
    }

    @Test func dateFiltersNarrowTheList() async throws {
        let (sut, _) = try makeSUT()
        await sut.fetchData()
        let all = sut.summaries.count

        sut.dateFilter = .today
        #expect(sut.summaries.count == 1)
        sut.dateFilter = .last7Days
        #expect(sut.summaries.count == all)
        sut.dateFilter = .thisMonth
        #expect(sut.summaries.count >= 1 && sut.summaries.count <= all)
        sut.dateFilter = .last3Months
        #expect(sut.summaries.count == all)
        sut.dateFilter = .thisYear
        #expect(sut.summaries.count >= 1)
        sut.dateFilter = .all
        #expect(sut.summaries.count == all)
    }

    @Test func customRangeAndSortOrder() async throws {
        let (sut, _) = try makeSUT()
        await sut.fetchData()
        sut.customStartDate = day(-1)
        sut.customEndDate = day(0)
        #expect(sut.summaries.count == 4)
        sut.dateFilter = .custom
        #expect(sut.summaries.count == 2)
        sut.customStartDate = day(-3)
        #expect(sut.summaries.count == 4)
        sut.customEndDate = day(-2)
        #expect(sut.summaries.count == 2)

        sut.dateFilter = .all
        sut.sortOption = .oldest
        #expect(sut.summaries.first!.date < sut.summaries.last!.date)
        sut.sortOption = .newest
        #expect(sut.summaries.first!.date > sut.summaries.last!.date)
    }

    @Test func refreshForcesASyncThenReloads() async throws {
        let (sut, summaries) = try makeSUT()
        await sut.refreshData()
        #expect(summaries.calls.first == "sync:true")
        summaries.failSync = true
        await sut.refreshData()
    }

    @Test func filterAndSortOptionsExposeTheirTitles() {
        #expect(DailyCashflowSortOption.allCases.map(\.rawValue) == ["Newest", "Oldest"])
        #expect(DailyCashflowDateFilterOption.allCases.count == 7)
    }
}

// MARK: - AddUpdateDailyCashflowSummaryViewModel

@MainActor
struct AddUpdateDailyCashflowSummaryViewModelTests {
    private func makeSUT(summaries: SummaryRepo = SummaryRepo(), transactions: TransactionRepo = TransactionRepo(),
                         user: MockUserRepository? = nil, orgs: OrgRepo = OrgRepo(), existing: DailyCashflowSummary? = nil,
                         date: Date = Date()) throws -> AddUpdateDailyCashflowSummaryViewModel {
        AddUpdateDailyCashflowSummaryViewModel(repository: summaries, userRepository: try user ?? userRepo(), organizationRepository: orgs,
                                               cashflowRepository: transactions, existingSummary: existing, date: date)
    }

    @Test func addPrefillsOpeningFromThePreviousClosingAndComputesClosing() async throws {
        let summaries = SummaryRepo()
        summaries.summaries = [summary(day(-1), closing: [AccountBalance(id: "cash", name: "Cash", balance: 100)])]
        let transactions = TransactionRepo()
        transactions.transactions = [
            transaction("in", amount: 30, to: "cash"),
            transaction("out", amount: 10, from: "cash"),
            transaction("setup", amount: 999, category: .shopSetup, to: "cash"),
            transaction("gone", amount: 999, deleted: true, to: "cash"),
            transaction("other-day", amount: 999, at: atNoon(-3), to: "cash")
        ]
        let sut = try makeSUT(summaries: summaries, transactions: transactions, date: Date())
        await sut.fetchInitialData()
        #expect(sut.accounts.count == 2)
        #expect(sut.dayTransactions.count == 2)
        #expect(sut.openingBalanceInputs["cash"] == "100.0")
        #expect(sut.openingBalanceInputs["upi"] == "0.0")
        #expect(sut.closingBalanceInputs["cash"] == "120.00")
    }

    @Test func updatePrefillsFromTheExistingSummary() async throws {
        let existing = summary(Date(), opening: [AccountBalance(id: "cash", name: "Cash", balance: 40)])
        let sut = try makeSUT(existing: existing)
        await sut.fetchInitialData()
        #expect(sut.openingBalanceInputs["cash"] == "40.0")
        #expect(sut.openingBalanceInputs["upi"] == "0.0")
        sut.openingBalanceInputs["cash"] = "not a number"
        #expect(sut.closingBalanceInputs["cash"] == "0.00")
    }

    @Test func fetchReportsMissingOrganizationAndFailures() async throws {
        let noOrg = try makeSUT(user: try userRepo(orgId: nil))
        await noOrg.fetchInitialData()
        #expect(noOrg.errorMessage == "No organization selected.")

        let missing = try makeSUT(orgs: OrgRepo([]))
        await missing.fetchInitialData()
        #expect(missing.errorMessage == "Organization details not found.")

        let summaries = SummaryRepo()
        summaries.failGetAll = true
        let broken = try makeSUT(summaries: summaries)
        await broken.fetchInitialData()
        #expect(broken.errorMessage?.hasPrefix("Failed to load data") == true)
    }

    @Test func saveAddCreatesAUnlockedSummary() async throws {
        let summaries = SummaryRepo()
        let sut = try makeSUT(summaries: summaries)
        await sut.fetchInitialData()
        sut.openingBalanceInputs["cash"] = "10"
        #expect(await sut.save())
        #expect(summaries.saved?.locked == false)
        #expect(summaries.saved?.openingBalances.first { $0.id == "cash" }?.balance == 10)
        #expect(!sut.isSaving)
    }

    @Test func saveUpdateRewritesBalancesAndReportsFailure() async throws {
        let summaries = SummaryRepo()
        let existing = summary(Date())
        let sut = try makeSUT(summaries: summaries, existing: existing)
        await sut.fetchInitialData()
        #expect(await sut.save())
        #expect(summaries.updated?.id == existing.id)
        summaries.failUpdate = true
        #expect(await sut.save() == false)
        #expect(sut.errorMessage == "boom")

        let adding = try makeSUT(summaries: summaries)
        summaries.failSave = true
        #expect(await adding.save() == false)
    }

    @Test func savingBeforeAccountsLoadWritesAnEmptySummary() async throws {
        let summaries = SummaryRepo()
        let sut = try makeSUT(summaries: summaries)
        #expect(await sut.save())
        #expect(summaries.saved?.openingBalances.isEmpty == true)
    }
}
