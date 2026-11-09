//
//  ModulesContainer.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaModules
import ApoorvaServices
import ApoorvaRepository
import ApoorvaModels
import ApoorvaUtilities
import ApoorvaEnvironment

// In ApoorvaPOS Module
@MainActor
public class ModulesContainer {
    private let servicesContainer: ServicesContainer
    private let repositoryContainer: RepositoryContainer
    private let environment: AppEnvironment

//    // Feature-specific repositories (lazy so they don't consume memory until POS is opened)
//    private lazy var posRepository: PosRepositoryProtocol = {
//        PosRepository(api: core.apiClient, storage: core.offlineStorage)
//    }()

    public init(servicesContainer: ServicesContainer,
                repositoryContainer: RepositoryContainer,
                environment: AppEnvironment) {
        self.servicesContainer = servicesContainer
        self.repositoryContainer = repositoryContainer
        self.environment = environment
    }

    public func makeLoginViewModel() -> LoginViewModel {
        return LoginViewModel(
            authService: servicesContainer.authService,
            environment: environment
        )
    }
    
    // MARK: - Onboarding & auth

    public func makeAuthFlowViewModel() -> AuthFlowViewModel {
        AuthFlowViewModel(authService: servicesContainer.authService)
    }

    public func makeShopSetupViewModel(trialDays: @escaping () -> Int) -> ShopSetupViewModel {
        ShopSetupViewModel(authService: servicesContainer.authService,
                           setupService: servicesContainer.organizationSetupService,
                           platformTrialDays: trialDays)
    }

    public func makeOpeningBalancesViewModel(session: AppSession) -> OpeningBalancesViewModel {
        OpeningBalancesViewModel(session: session,
                                 customerRepository: repositoryContainer.customerRepository,
                                 ledgerRepository: repositoryContainer.customerLedgerRepository,
                                 supplierRepository: repositoryContainer.supplierRepository,
                                 dailyCashflowRepository: repositoryContainer.dailyCashflowRepository,
                                 organizationRepository: repositoryContainer.organizationRepository)
    }

    public func makeStaffJoinViewModel(code: String, currentOrgs: @escaping () -> [OrganizationSnapshot]) -> StaffJoinViewModel {
        StaffJoinViewModel(code: code, setupService: servicesContainer.organizationSetupService,
                           authService: servicesContainer.authService, currentOrgs: currentOrgs)
    }

    public func makePinSwitchViewModel(session: AppSession) -> PinSwitchViewModel {
        PinSwitchViewModel(session: session, memberRepository: repositoryContainer.memberRepository,
                           pinStore: servicesContainer.pinStore, biometrics: servicesContainer.biometrics)
    }

    public func makeDemoSeeder() -> DemoSeeder {
        DemoSeeder(inventoryRepository: repositoryContainer.inventoryRepository,
                   customerRepository: repositoryContainer.customerRepository,
                   saleRepository: repositoryContainer.saleRepository)
    }

    public func makePOSViewModel() -> POSViewModel {
        return POSViewModel(
            inventoryRepository: repositoryContainer.inventoryRepository,
            heldBillRepository: repositoryContainer.heldBillRepository,
            memberRepository: repositoryContainer.memberRepository,
            customerRepository: repositoryContainer.customerRepository,
            categoryLoader: { [categoryRepository = repositoryContainer.categoryRepository] in
                let categories = ((try? await categoryRepository.all()) ?? []).filter { !$0.isDeleted }
                return Dictionary(categories.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
            }
        )
    }

    public func makeLineEditViewModel(line: CartItem, isNew: Bool) -> LineEditViewModel {
        LineEditViewModel(line: line, isNew: isNew)
    }

    /// Bill discount capped by the member's role; managers and owners on this device can approve more.
    public func makeBillDiscountViewModel(cart: PosCart, session: AppSession) async -> BillDiscountViewModel {
        let approvers = ((try? await repositoryContainer.memberRepository.all()) ?? [])
            .filter { $0.isActive && ($0.role == .owner || $0.role == .manager) }
        return BillDiscountViewModel(subtotal: cart.totalFinalPrice, currentAmount: cart.flatDiscount,
                                     currentPercent: cart.discountPercent,
                                     limitPercent: session.can(.discountAboveLimit) ? 100 : session.discountLimitPercent,
                                     managers: approvers, pinStore: servicesContainer.pinStore)
    }

    public func makePackagesViewModel(customerPhone: String?, customerName: String) -> PackagesViewModel {
        PackagesViewModel(customerPhone: customerPhone, customerName: customerName,
                          packages: repositoryContainer.servicePackageRepository,
                          customerPackages: repositoryContainer.customerPackageRepository,
                          audit: repositoryContainer.auditLogger)
    }

    public func recordPackagePurchases(in sale: Sale) async {
        await PackagesViewModel.recordPurchases(in: sale, packages: repositoryContainer.servicePackageRepository,
                                                customerPackages: repositoryContainer.customerPackageRepository)
    }

    public func makeReturnViewModel(saleId: String, session: AppSession) -> ReturnViewModel {
        ReturnViewModel(saleId: saleId, saleRepository: repositoryContainer.saleRepository,
                        lifecycle: repositoryContainer.saleLifecycleRepository, session: session)
    }

    public func makeCustomerPickerViewModel() -> CustomerPickerViewModel {
        return CustomerPickerViewModel(
            repository: repositoryContainer.customerRepository
        )
    }

    public func makeHeldBillsViewModel() -> HeldBillsViewModel {
        return HeldBillsViewModel(
            repository: repositoryContainer.heldBillRepository
        )
    }

    public func makeCheckoutViewModel(cart: PosCart, heldBillId: String?, session: AppSession? = nil) -> CheckoutViewModel {
        return CheckoutViewModel(
            cart: cart,
            heldBillId: heldBillId,
            saleRepository: repositoryContainer.saleRepository,
            userRepository: repositoryContainer.userRepository,
            lifecycle: repositoryContainer.saleLifecycleRepository,
            session: session
        )
    }

    public func makeReceiptViewModel(saleId: String, session: AppSession? = nil, cashReceived: Double? = nil) -> ReceiptViewModel {
        return ReceiptViewModel(
            saleId: saleId,
            saleRepository: repositoryContainer.saleRepository,
            session: session,
            cashReceived: cashReceived
        )
    }
    
    public func makeProfileViewModel() -> ProfileViewModel {
        return ProfileViewModel(
            userRepository: repositoryContainer.userRepository,
            authService: servicesContainer.authService,
            clearLocalData: { [repositoryContainer] in
                try? repositoryContainer.clearLocalData()
            }
        )
    }

    public func makeUserListViewModel() -> UserListViewModel {
        return UserListViewModel(
            userRepository: repositoryContainer.userRepository
        )
    }

    public func makeOrganizationListViewModel() -> OrganizationListViewModel {
        return OrganizationListViewModel(
            userRepository: repositoryContainer.userRepository
        )
    }
    
    // MARK: - Stock (73–82)

    public func makeInventoryViewModel() -> InventoryViewModel {
        InventoryViewModel(inventoryRepository: repositoryContainer.inventoryRepository,
                           categoryRepository: repositoryContainer.categoryRepository)
    }

    public func makeInventoryItemViewModel(itemId: String) -> InventoryItemViewModel {
        InventoryItemViewModel(itemId: itemId, inventoryRepository: repositoryContainer.inventoryRepository,
                               saleRepository: repositoryContainer.saleRepository,
                               movementRepository: repositoryContainer.stockMovementRepository,
                               categoryRepository: repositoryContainer.categoryRepository)
    }

    public func makeStockAdjustViewModel(itemId: String, actorId: String) -> StockAdjustViewModel {
        StockAdjustViewModel(itemId: itemId, inventoryRepository: repositoryContainer.inventoryRepository,
                             stock: repositoryContainer.stockRepository, actorId: actorId)
    }

    public func makeItemFormViewModel(itemId: String?) -> ItemFormViewModel {
        ItemFormViewModel(itemId: itemId, inventoryRepository: repositoryContainer.inventoryRepository,
                          categoryRepository: repositoryContainer.categoryRepository, audit: repositoryContainer.auditLogger)
    }

    public func makeCategoriesViewModel() -> CategoriesViewModel {
        CategoriesViewModel(repository: repositoryContainer.categoryRepository, inventoryRepository: repositoryContainer.inventoryRepository)
    }

    public func makeItemImportViewModel() -> ItemImportViewModel {
        ItemImportViewModel(inventoryRepository: repositoryContainer.inventoryRepository,
                            categoryRepository: repositoryContainer.categoryRepository, audit: repositoryContainer.auditLogger)
    }

    public func makeReorderViewModel(session: AppSession) -> ReorderViewModel {
        ReorderViewModel(inventoryRepository: repositoryContainer.inventoryRepository,
                         supplierRepository: repositoryContainer.supplierRepository, shopName: session.displayShopName)
    }

    public func makeSuppliersViewModel() -> SuppliersViewModel {
        SuppliersViewModel(repository: repositoryContainer.supplierRepository, ledgerRepository: repositoryContainer.supplierLedgerRepository)
    }

    public func makeSupplierFormViewModel() -> SupplierFormViewModel {
        SupplierFormViewModel(repository: repositoryContainer.supplierRepository)
    }

    public func makeSupplierDetailViewModel(supplierId: String, actorId: String) -> SupplierDetailViewModel {
        SupplierDetailViewModel(supplierId: supplierId, repository: repositoryContainer.supplierRepository,
                                ledgerRepository: repositoryContainer.supplierLedgerRepository,
                                stock: repositoryContainer.stockRepository, actorId: actorId)
    }

    public func makePurchaseFormViewModel(supplierId: String?, lines: [PurchaseLine], actorId: String) -> PurchaseFormViewModel {
        PurchaseFormViewModel(supplierId: supplierId, prefill: lines, supplierRepository: repositoryContainer.supplierRepository,
                              purchaseRepository: repositoryContainer.purchaseRepository,
                              inventoryRepository: repositoryContainer.inventoryRepository,
                              stock: repositoryContainer.stockRepository, actorId: actorId)
    }

    // MARK: - Money (83–95)

    public func makeCashDayViewModel(date: Date = Date()) -> CashDayViewModel {
        CashDayViewModel(date: date, summaries: repositoryContainer.dailyCashflowRepository, saleRepository: repositoryContainer.saleRepository,
                         cashflowRepository: repositoryContainer.cashflowRepository, dayCloses: repositoryContainer.dayCloseRepository)
    }

    public func makeCashEntryViewModel(actorId: String) -> CashEntryViewModel {
        CashEntryViewModel(money: repositoryContainer.moneyRepository, actorId: actorId)
    }

    public func makeDayCloseViewModel(date: Date, session: AppSession) -> DayCloseViewModel {
        DayCloseViewModel(date: date, dayViewModel: makeCashDayViewModel(date: date), money: repositoryContainer.moneyRepository,
                          actorId: session.actorId, actorName: session.actorName)
    }

    public func makeCashHistoryViewModel(actorId: String) -> CashHistoryViewModel {
        CashHistoryViewModel(dayCloses: repositoryContainer.dayCloseRepository, saleRepository: repositoryContainer.saleRepository,
                             money: repositoryContainer.moneyRepository, actorId: actorId)
    }

    public func makeExpensesViewModel() -> ExpensesViewModel {
        ExpensesViewModel(repository: repositoryContainer.expenseRepository)
    }

    public func makeExpenseFormViewModel(expenseId: String?, actorId: String) -> ExpenseFormViewModel {
        ExpenseFormViewModel(expenseId: expenseId, repository: repositoryContainer.expenseRepository,
                             money: repositoryContainer.moneyRepository, actorId: actorId)
    }

    public func makeDailySummaryViewModel(session: AppSession) -> DailySummaryViewModel {
        DailySummaryViewModel(saleRepository: repositoryContainer.saleRepository, inventoryRepository: repositoryContainer.inventoryRepository,
                              ledger: repositoryContainer.customerLedgerRepository, expenseRepository: repositoryContainer.expenseRepository,
                              dayCloses: repositoryContainer.dayCloseRepository, shopName: session.displayShopName)
    }

    public func makeInsightsViewModel(session: AppSession) -> InsightsViewModel {
        InsightsViewModel(saleRepository: repositoryContainer.saleRepository, inventoryRepository: repositoryContainer.inventoryRepository,
                          customerRepository: repositoryContainer.customerRepository, memberRepository: repositoryContainer.memberRepository,
                          expenseRepository: repositoryContainer.expenseRepository, ledgerRepository: repositoryContainer.customerLedgerRepository,
                          cashflowRepository: repositoryContainer.cashflowRepository, categoryRepository: repositoryContainer.categoryRepository,
                          shopName: session.displayShopName, discountLimit: session.discountLimitPercent,
                          taxIsOn: session.settings.tax.mode != .off)
    }

    // MARK: - People (71, 72)

    public func makeAttendanceViewModel(actorId: String) -> AttendanceViewModel {
        AttendanceViewModel(memberRepository: repositoryContainer.memberRepository, attendanceRepository: repositoryContainer.attendanceRepository,
                            people: repositoryContainer.peopleRepository, actorId: actorId)
    }

    public func makeSalaryViewModel(actorId: String) -> SalaryViewModel {
        SalaryViewModel(memberRepository: repositoryContainer.memberRepository, attendanceRepository: repositoryContainer.attendanceRepository,
                        salaryRepository: repositoryContainer.salaryPaymentRepository, saleRepository: repositoryContainer.saleRepository,
                        people: repositoryContainer.peopleRepository, actorId: actorId)
    }
    
    public func makeCustomerListViewModel() -> CustomerListViewModel {
        return CustomerListViewModel(
            repository: repositoryContainer.customerRepository
        )
    }

    // MARK: - Customers (62–69)

    public func makeCustomerDetailViewModel(phone: String) -> CustomerDetailViewModel {
        CustomerDetailViewModel(phone: phone, customerRepository: repositoryContainer.customerRepository,
                                saleRepository: repositoryContainer.saleRepository, dues: repositoryContainer.duesRepository)
    }

    public func makeCustomerFormViewModel(phone: String?) -> CustomerFormViewModel {
        CustomerFormViewModel(phone: phone, repository: repositoryContainer.customerRepository)
    }

    public func makeCollectDueViewModel(phone: String, actorId: String) -> CollectDueViewModel {
        CollectDueViewModel(phone: phone, customerRepository: repositoryContainer.customerRepository,
                            dues: repositoryContainer.duesRepository, actorId: actorId)
    }

    public func makeDueReminderViewModel(phone: String, session: AppSession) -> DueReminderViewModel {
        DueReminderViewModel(phone: phone, customerRepository: repositoryContainer.customerRepository,
                             shopName: session.displayShopName, upiId: session.settings.payments.upiId)
    }

    public func makeStatementViewModel(phone: String, session: AppSession) -> StatementViewModel {
        StatementViewModel(phone: phone, customerRepository: repositoryContainer.customerRepository,
                           dues: repositoryContainer.duesRepository, shopName: session.displayShopName)
    }

    public func makeImportContactsViewModel() -> ImportContactsViewModel {
        ImportContactsViewModel(provider: DeviceContactsProvider(), repository: repositoryContainer.customerRepository)
    }

    public func makeOffersViewModel(session: AppSession) -> OffersViewModel {
        OffersViewModel(repository: repositoryContainer.customerRepository, shopName: session.displayShopName)
    }

    // MARK: - Sell (58–60, 63)

    public func makeOrdersViewModel() -> OrdersViewModel {
        OrdersViewModel(repository: repositoryContainer.orderRepository)
    }

    public func makeOrderFormViewModel(session: AppSession) -> OrderFormViewModel {
        OrderFormViewModel(orders: repositoryContainer.orderRepository, customerRepository: repositoryContainer.customerRepository,
                           dues: repositoryContainer.duesRepository, audit: repositoryContainer.auditLogger,
                           actorId: session.actorId, actorName: session.actorName)
    }

    public func makeOrderDetailViewModel(orderId: String, session: AppSession) -> OrderDetailViewModel {
        OrderDetailViewModel(orderId: orderId, repository: repositoryContainer.orderRepository,
                             audit: repositoryContainer.auditLogger, shopName: session.displayShopName)
    }

    public func markOrdersDelivered(in sale: Sale) async {
        await OrderDeliveries.markDelivered(in: sale, repository: repositoryContainer.orderRepository,
                                            audit: repositoryContainer.auditLogger)
    }

    public func makeWarrantyViewModel(actorId: String) -> WarrantyViewModel {
        WarrantyViewModel(saleRepository: repositoryContainer.saleRepository,
                          claimRepository: repositoryContainer.warrantyClaimRepository,
                          audit: repositoryContainer.auditLogger, actorId: actorId)
    }
    
    // MARK: - Home & bills

    public func makeHomeViewModel(session: AppSession) -> HomeViewModel {
        HomeViewModel(session: session,
                      saleRepository: repositoryContainer.saleRepository,
                      customerRepository: repositoryContainer.customerRepository,
                      inventoryRepository: repositoryContainer.inventoryRepository,
                      dailyCashflowRepository: repositoryContainer.dailyCashflowRepository)
    }

    public func makeBillsViewModel() -> BillsViewModel {
        BillsViewModel(repository: repositoryContainer.saleRepository, memberRepository: repositoryContainer.memberRepository)
    }

    public func makeBillDetailViewModel(saleId: String) -> BillDetailViewModel {
        BillDetailViewModel(saleId: saleId, repository: repositoryContainer.saleRepository,
                            memberRepository: repositoryContainer.memberRepository)
    }

    public func makeCancelBillViewModel(saleId: String, actorId: String) -> CancelBillViewModel {
        CancelBillViewModel(saleId: saleId, lifecycle: repositoryContainer.saleLifecycleRepository, actorId: actorId)
    }

    public func makeBillEditViewModel(saleId: String, actorId: String) -> BillEditViewModel {
        BillEditViewModel(saleId: saleId, repository: repositoryContainer.saleRepository,
                          lifecycle: repositoryContainer.saleLifecycleRepository, actorId: actorId)
    }

    public func makeCashflowTransactionListViewModel() -> CashflowTransactionListViewModel {
        return CashflowTransactionListViewModel(
            repository: repositoryContainer.cashflowRepository
        )
    }
    
    public func makeDailyCashflowViewModel(selectedDate: Date? = nil) -> DailyCashFlowViewModel {
        return DailyCashFlowViewModel(
            repository: repositoryContainer.dailyCashflowRepository,
            userRepository: repositoryContainer.userRepository,
            organizationRepository: repositoryContainer.organizationRepository,
            cashflowRepository: repositoryContainer.cashflowRepository,
            selectedDate: selectedDate
        )
    }
    
    public func makeDailyCashflowListViewModel() -> DailyCashFlowListViewModel {
        return DailyCashFlowListViewModel(
            repository: repositoryContainer.dailyCashflowRepository,
            userRepository: repositoryContainer.userRepository,
            organizationRepository: repositoryContainer.organizationRepository,
            cashflowRepository: repositoryContainer.cashflowRepository
        )
    }
    
    public func makeAddUpdateDailyCashflowViewModel(existingSummary: DailyCashflowSummary?, date: Date) -> AddUpdateDailyCashflowSummaryViewModel {
        return AddUpdateDailyCashflowSummaryViewModel(
            repository: repositoryContainer.dailyCashflowRepository,
            userRepository: repositoryContainer.userRepository,
            organizationRepository: repositoryContainer.organizationRepository,
            cashflowRepository: repositoryContainer.cashflowRepository,
            existingSummary: existingSummary,
            date: date
        )
    }
    
    public func makeAddUpdateCashflowTransactionViewModel(existingTransaction: CashflowTransaction?,
                                                          defaultDate: Date) -> AddUpdateCashflowTransactionViewModel {
        return AddUpdateCashflowTransactionViewModel(
            repository: repositoryContainer.cashflowRepository,
            userRepository: repositoryContainer.userRepository,
            organizationRepository: repositoryContainer.organizationRepository,
            existingTransaction: existingTransaction,
            defaultDate: defaultDate
        )
    }
}
