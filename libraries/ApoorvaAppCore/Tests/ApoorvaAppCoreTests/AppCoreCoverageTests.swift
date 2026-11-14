//
//  AppCoreCoverageTests.swift
//  ApoorvaAppCore
//

import Testing
import Foundation
import SwiftUI
import FirebaseCore
import ApoorvaModels
import ApoorvaModules
import ApoorvaServices
import ApoorvaEnvironment
import ManiLogger
@testable import ApoorvaAppCore

/// The containers build real Firebase-backed services; a configured (but fake and offline) app keeps them from trapping.
let configureFakeFirebase: Void = {
    if FirebaseApp.app() == nil {
        let options = FirebaseOptions(googleAppID: "1:1234567890:ios:0123456789abcdef", gcmSenderID: "1234567890")
        options.apiKey = "AIzaSy000000000000000000000000000000000"
        options.projectID = "fake-project"
        FirebaseApp.configure(options: options)
    }
}()

// MARK: - Routes

struct RouteIdentityTests {
    @Test func routesAreTheirOwnIdentity() {
        #expect(GlobalRoute.search.id == .search)
        #expect(OnboardingRoute.splash.id == .splash)
        #expect(CustomersRoute.add.id == .add)
        #expect(NewBillRoute.checkout.id == .checkout)
        #expect(NewBillSheet.discount.id == .discount)
        #expect(MoreRoute.help.id == .help)
        let placeholder = PlaceholderScreen("Soon")
        #expect(placeholder.id == "Soon" && placeholder.title == "Soon")
    }

    @Test func quickGridSheetsAreHalfHeight() {
        for sheet in [NewBillSheet.find, .quickAdd(itemId: "i"), .quickEdit(lineId: "l")] {
            #expect(sheet.isHalfSheet)
        }
        for sheet in [NewBillSheet.weight(itemId: "i"), .customItem, .variant(itemId: "i"), .discount] {
            #expect(!sheet.isHalfSheet)
        }
    }
}

// MARK: - Coordinators

@MainActor
struct CoordinatorNavigationTests {
    @Test func newBillCoordinatorStacksSheetsAndHandsOverTheCartOnce() {
        let coordinator = NewBillCoordinator()
        coordinator.push(.checkout)
        coordinator.push(.split)
        coordinator.pop()
        #expect(coordinator.path == [.checkout])
        coordinator.popToRoot()
        #expect(coordinator.path.isEmpty)
        coordinator.present(.discount)
        #expect(coordinator.presentedSheet == .discount)
        coordinator.dismissSheet()
        #expect(coordinator.presentedSheet == nil)

        #expect(coordinator.takePendingCart() == nil)
        coordinator.pendingCart = PosCart()
        coordinator.pendingHeldBillId = "h1"
        let taken = coordinator.takePendingCart()
        #expect(taken?.heldBillId == "h1")
        #expect(coordinator.pendingCart == nil && coordinator.pendingHeldBillId == nil)
    }

    @Test func billsCustomersAndMoreCoordinatorsPushAndPop() {
        let bills = BillsCoordinator()
        bills.push(.detail(billId: "1"))
        bills.push(.cancel(billId: "1"))
        bills.pop()
        #expect(bills.path == [.detail(billId: "1")])
        bills.popToRoot()
        #expect(bills.path.isEmpty)

        let customers = CustomersCoordinator()
        customers.push(.add)
        customers.push(.offers)
        customers.pop()
        customers.popToRoot()
        #expect(customers.path.isEmpty)

        let more = MoreCoordinator()
        more.push(.help)
        more.push(.sell(.orders))
        more.pop()
        #expect(more.path == [.help])
        more.popToRoot()
        #expect(more.path.isEmpty)
    }

    @Test func homeCoordinatorPresentsSheets() {
        let home = HomeCoordinator()
        home.present(.planUsage)
        #expect(home.presentedSheet == .planUsage)
        home.dismissSheet()
        #expect(home.presentedSheet == nil)
    }

    @Test func onboardingCoordinatorPopsAndResets() {
        let coordinator = OnboardingCoordinator(container: AppContainer())
        coordinator.push(.register)
        coordinator.push(.emailSignIn)
        coordinator.pop()
        #expect(coordinator.path == [.register])
        coordinator.popToRoot()
        #expect(coordinator.path.isEmpty)
    }

    @Test func tabsCoordinatorRoutesAcrossTabs() {
        let tabs = HomeTabsCoordinator(container: AppContainer())
        tabs.newBillCoordinator.push(.checkout)
        tabs.startBill(with: PosCart(), heldBillId: "h")
        #expect(tabs.isPresentingNewBill)
        #expect(tabs.newBillCoordinator.path.isEmpty)
        #expect(tabs.newBillCoordinator.pendingHeldBillId == "h")

        tabs.showLocked("Owner only")

        tabs.showMore(.help)
        #expect(tabs.selectedTab == .more && tabs.moreCoordinator.path == [.help])

        tabs.showCustomers(.add)
        #expect(tabs.selectedTab == .customers && tabs.customersCoordinator.path == [.add])
        tabs.showCustomers()
        #expect(tabs.customersCoordinator.path.isEmpty)

        tabs.showBill("s1")
        #expect(tabs.selectedTab == .bills && tabs.billsCoordinator.path == [.detail(billId: "s1")])
        tabs.showBills()
        #expect(tabs.billsCoordinator.path.isEmpty)
    }
}

// MARK: - Small helpers

struct LaunchEnvironmentTests {
    @Test func resolvesTheStoredEnvironmentAndLooksForItsPlist() {
        #expect(AppEnvironment.allCases.contains(LaunchEnvironment.current))
        _ = LaunchEnvironment.firebasePlistPath(in: Bundle(for: BundleToken.self))
    }

    private final class BundleToken {}
}

@MainActor
struct RetainedViewTests {
    @Test func retainedHoldsTheModelAndBuildsContent() {
        let view = Retained(NSObject()) { _ in Text("content") }
        _ = view.body
    }
}

private final class RecordingCrashService: CrashReportingServicing, @unchecked Sendable {
    var logs: [String] = []
    func recordNonFatal(_ error: Error, context: String) {}
    func setCustomKey(_ value: String, forKey key: String) {}
    func setUserId(_ id: String?) {}
    func log(_ message: String) { logs.append(message) }
}

struct CrashReportingLogSinkTests {
    @Test func onlyWarningsAndAboveReachTheCrashReporter() async throws {
        let crash = RecordingCrashService()
        LogSinks.shared.configure(sinks: [], minimumLevel: .debug)
        LogSinks.shared.add(CrashReportingLogSink(crashReportingService: crash))
        let logger = AppLogger(category: .app)
        logger.debug("quiet detail")
        logger.error("loud failure")
        for _ in 0..<40 where crash.logs.isEmpty { try await Task.sleep(nanoseconds: 50_000_000) }
        #expect(crash.logs.contains { $0.contains("loud failure") })
        #expect(!crash.logs.contains { $0.contains("quiet detail") })
    }
}

struct DebugRemoteConfigOverrideCoverageTests {
    private func makeService(_ overrides: [String: String] = [:]) -> (DebugRemoteConfigOverrideService, NoOpRemoteConfigService) {
        let base = NoOpRemoteConfigService()
        let tools = StubDeveloperTools()
        tools.remoteConfigOverrides = overrides
        return (DebugRemoteConfigOverrideService(base: base, developerTools: tools), base)
    }

    @Test func fetchAndDefaultsGoStraightToTheBase() async throws {
        let (service, base) = makeService()
        try await service.fetchAndActivate()
        service.setDefaults(["s": .string("x"), "n": .number(3), "j": .json(Data("{\"enabled\":true}".utf8))])
        base.markRemote(["s"])
        #expect(service.isRemoteValue(forKey: "s"))
        #expect(!service.isRemoteValue(forKey: "n"))
        #expect(service.stringValue(forKey: "s") == "x")
        #expect(service.numberValue(forKey: "n") == 3)
    }

    @Test func numberAndJsonOverridesApplyOnlyWhenValid() {
        let (service, _) = makeService(["n": "7.5", "bad": "nope", "j": "{\"enabled\":true}", "badJson": "{"])
        #expect(service.numberValue(forKey: "n") == 7.5)
        #expect(service.numberValue(forKey: "bad") == nil)
        #expect(service.boolValue(forKey: "bad") == false)
        let gate = service.jsonValue(forKey: "j", as: VersionGateValue.self)
        #expect(gate?.enabled == true)
        #expect(service.jsonValue(forKey: "badJson", as: VersionGateValue.self) == nil)
        #expect(service.stringValue(forKey: "n") == "7.5")
    }
}

// MARK: - Containers

@MainActor
struct ContainerWiringTests {
    @Test func servicesContainerBuildsEveryService() {
        _ = configureFakeFirebase
        let services = ServicesContainer()
        _ = services.authService
        _ = services.userService
        _ = services.inventoryService
        _ = services.customerService
        _ = services.saleService
        _ = services.cashflowService
        _ = services.dailyCashflowService
        _ = services.organizationService
        _ = services.heldBillService
        _ = services.platformConfigService
        _ = services.organizationSetupService
        _ = services.pinStore
        _ = services.biometrics
        _ = services.analyticsService
        _ = services.crashReportingService
        _ = services.performanceMonitoringService
        _ = services.remoteConfigService
    }

    @Test func offlineStorageUsesAnEnvironmentSpecificDatabaseFile() {
        let production = OfflineStorageContainer(environment: .production)
        #expect(production.databasePath.hasSuffix("apoorva.sqlite"))
        let debug = OfflineStorageContainer(environment: .debug)
        #expect(debug.databasePath.hasSuffix(AppEnvironment.debug.dbFileName()))
    }

    @Test func offlineStorageBuildsEveryStorage() {
        let storage = OfflineStorageContainer(environment: .debug)
        _ = storage.skipSqlDatabase
        _ = storage.userDefaultsStorage
        _ = storage.inventoryItemsLocalStorage
        _ = storage.customersLocalStorage
        _ = storage.salesLocalStorage
        _ = storage.cashflowLocalStorage
        _ = storage.dailyCashflowStorage
        _ = storage.organizationStorage
        _ = storage.heldBillsLocalStorage
        _ = storage.syncStorage
    }

    @Test func repositoryContainerBuildsEveryRepositoryAndClearsLocalData() async throws {
        _ = configureFakeFirebase
        let container = AppContainer()
        let repositories = container.repositoryContainer
        _ = repositories.userRepository
        _ = repositories.inventoryRepository
        _ = repositories.customerRepository
        _ = repositories.heldBillRepository
        _ = repositories.saleRepository
        _ = repositories.cashflowRepository
        _ = repositories.dailyCashflowRepository
        _ = repositories.organizationRepository
        _ = repositories.orgContext
        _ = repositories.auditRepository
        _ = repositories.customerLedgerRepository
        _ = repositories.stockMovementRepository
        _ = repositories.auditLogger
        _ = repositories.settingsRepository
        _ = repositories.storeRepository
        _ = repositories.memberRepository
        _ = repositories.supplierRepository
        _ = repositories.servicePackageRepository
        _ = repositories.customerPackageRepository
        _ = repositories.orderRepository
        _ = repositories.warrantyClaimRepository
        _ = repositories.categoryRepository
        _ = repositories.purchaseRepository
        _ = repositories.supplierLedgerRepository
        _ = repositories.expenseRepository
        _ = repositories.dayCloseRepository
        _ = repositories.attendanceRepository
        _ = repositories.salaryPaymentRepository
        _ = repositories.cashBook
        _ = repositories.stockRepository
        _ = repositories.moneyRepository
        _ = repositories.peopleRepository
        _ = repositories.duesRepository
        _ = repositories.saleLifecycleRepository
        _ = repositories.syncEngine
        try await repositories.clearLocalData()
    }

    @Test func appContainerExposesConfigSessionAndDeveloperTools() {
        _ = configureFakeFirebase
        let container = AppContainer()
        _ = container.appConfig
        _ = container.appSession
        _ = container.modulesContainer
        #expect(!container.appVersion.isEmpty)
        #if DEBUG
        #expect(container.showsDeveloperTools)
        #expect(container.makeDeveloperSettingsViewModel() != nil)
        #expect(container.makeFlagOverridesViewModel() != nil)
        #expect(container.makeLogViewerViewModel() != nil)
        container.onConfigChanged = {}
        #else
        #expect(!container.showsDeveloperTools)
        #endif
    }
}

@MainActor
struct ModulesContainerTests {
    private func sale() -> Sale {
        Sale(id: "s1", staffId: "u", customerPhone: "9", customerName: "A", items: [], subtotal: 0, overallDiscountPercent: 0,
             overallDiscountAmount: 0, roundOff: 0, netPayable: 0, payments: [:], timestamp: Date(), source: "POS",
             status: "Completed", whatsappStatus: "unsent")
    }

    @Test func everyViewModelFactoryBuilds() async {
        _ = configureFakeFirebase
        let app = AppContainer()
        let modules = app.modulesContainer
        let session = app.appSession
        let line = CartItem(category: InventoryItem(id: "i", name: "Item"), mrp: 10, quantity: 1)

        _ = modules.makeLoginViewModel()
        _ = modules.makeAuthFlowViewModel()
        _ = modules.makeShopSetupViewModel(trialDays: { 30 })
        _ = modules.makeOpeningBalancesViewModel(session: session)
        _ = modules.makeStaffJoinViewModel(code: "ABC", currentOrgs: { [] })
        _ = modules.makePinSwitchViewModel(session: session)
        _ = modules.makeDemoSeeder()

        _ = modules.makePOSViewModel()
        _ = modules.makeLineEditViewModel(line: line, isNew: true)
        _ = modules.makeQuickAddLineViewModel(line: line, isNew: true)
        _ = await modules.makeBillDiscountViewModel(cart: PosCart(), session: session)
        _ = modules.makePackagesViewModel(customerPhone: "9", customerName: "A")
        await modules.recordPackagePurchases(in: sale())
        _ = modules.makeReturnViewModel(saleId: "s1", session: session)
        _ = modules.makeCustomerPickerViewModel()
        _ = modules.makeHeldBillsViewModel()
        _ = modules.makeCheckoutViewModel(cart: PosCart(), heldBillId: nil, session: session)
        _ = modules.makeCheckoutViewModel(cart: PosCart(), heldBillId: "h")
        _ = modules.makeReceiptViewModel(saleId: "s1", session: session, cashReceived: 10)
        _ = modules.makeReceiptViewModel(saleId: "s1")
        _ = modules.makeProfileViewModel()
        _ = modules.makeUserListViewModel()
        _ = modules.makeOrganizationListViewModel()

        _ = modules.makeInventoryViewModel()
        _ = modules.makeInventoryItemViewModel(itemId: "i")
        _ = modules.makeStockAdjustViewModel(itemId: "i", actorId: "u")
        _ = modules.makeItemFormViewModel(itemId: nil)
        _ = modules.makeCategoriesViewModel()
        _ = modules.makeItemImportViewModel()
        _ = modules.makeReorderViewModel(session: session)
        _ = modules.makeSuppliersViewModel()
        _ = modules.makeSupplierFormViewModel()
        _ = modules.makeSupplierDetailViewModel(supplierId: "s", actorId: "u")
        _ = modules.makePurchaseFormViewModel(supplierId: nil, lines: [PurchaseLine(itemId: "i", itemName: "Item", quantity: 1, unitCost: 1)],
                                              actorId: "u")

        _ = modules.makeCashDayViewModel()
        _ = modules.makeCashEntryViewModel(actorId: "u")
        _ = modules.makeDayCloseViewModel(date: Date(), session: session)
        _ = modules.makeCashHistoryViewModel(actorId: "u")
        _ = modules.makeExpensesViewModel()
        _ = modules.makeExpenseFormViewModel(expenseId: nil, actorId: "u")
        _ = modules.makeDailySummaryViewModel(session: session)
        _ = modules.makeInsightsViewModel(session: session)
        _ = modules.makeAttendanceViewModel(actorId: "u")
        _ = modules.makeSalaryViewModel(actorId: "u")

        _ = modules.makeCustomerListViewModel()
        _ = modules.makeCustomerDetailViewModel(phone: "9")
        _ = modules.makeCustomerFormViewModel(phone: nil)
        _ = modules.makeCollectDueViewModel(phone: "9", actorId: "u")
        _ = modules.makeDueReminderViewModel(phone: "9", session: session)
        _ = modules.makeStatementViewModel(phone: "9", session: session)
        _ = modules.makeImportContactsViewModel()
        _ = modules.makeOffersViewModel(session: session)

        _ = modules.makeOrdersViewModel()
        _ = modules.makeOrderFormViewModel(session: session)
        _ = modules.makeOrderDetailViewModel(orderId: "o", session: session)
        await modules.markOrdersDelivered(in: sale())
        _ = modules.makeWarrantyViewModel(actorId: "u")

        _ = modules.makeHomeViewModel(session: session)
        _ = modules.makeBillsViewModel()
        _ = modules.makeBillDetailViewModel(saleId: "s1")
        _ = modules.makeCancelBillViewModel(saleId: "s1", actorId: "u")
        _ = modules.makeBillEditViewModel(saleId: "s1", actorId: "u")
        _ = modules.makeCashflowTransactionListViewModel()
        _ = modules.makeDailyCashflowViewModel(selectedDate: nil)
        _ = modules.makeDailyCashflowListViewModel()
        _ = modules.makeAddUpdateDailyCashflowViewModel(existingSummary: nil, date: Date())
        _ = modules.makeAddUpdateCashflowTransactionViewModel(existingTransaction: nil, defaultDate: Date())
    }
}
