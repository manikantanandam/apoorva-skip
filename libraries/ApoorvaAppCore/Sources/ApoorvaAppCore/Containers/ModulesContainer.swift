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
            heldBillRepository: repositoryContainer.heldBillRepository
        )
    }

    public func makeItemPriceCalculatorViewModel(category: InventoryItem, existingItem: CartItem?) -> ItemPriceCalculatorViewModel {
        return ItemPriceCalculatorViewModel(category: category, existingItem: existingItem)
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

    public func makeReceiptViewModel(saleId: String) -> ReceiptViewModel {
        return ReceiptViewModel(
            saleId: saleId,
            saleRepository: repositoryContainer.saleRepository
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
    
    public func makeInventoryViewModel() -> InventoryViewModel {
        return InventoryViewModel(
            inventoryRepository: repositoryContainer.inventoryRepository,
            saleRepository: repositoryContainer.saleRepository
        )
    }
    
    public func makeCustomerListViewModel() -> CustomerListViewModel {
        return CustomerListViewModel(
            repository: repositoryContainer.customerRepository
        )
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
