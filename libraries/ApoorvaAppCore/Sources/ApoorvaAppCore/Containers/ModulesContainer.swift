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

// In ApoorvaPOS Module
@MainActor
public class ModulesContainer {
    private let servicesContainer: ServicesContainer
    private let repositoryContainer: RepositoryContainer
    
//    // Feature-specific repositories (lazy so they don't consume memory until POS is opened)
//    private lazy var posRepository: PosRepositoryProtocol = {
//        PosRepository(api: core.apiClient, storage: core.offlineStorage)
//    }()
    
    public init(servicesContainer: ServicesContainer,
                repositoryContainer: RepositoryContainer) {
        self.servicesContainer = servicesContainer
        self.repositoryContainer = repositoryContainer
    }
    
    public func makeLoginViewModel() -> LoginViewModel {
        return LoginViewModel(
            authService: servicesContainer.authService
        )
    }
    
    public func makePOSViewModel() -> POSViewModel {
        return POSViewModel(
            authService: servicesContainer.authService
        )
    }
    
    public func makeProfileViewModel() -> ProfileViewModel {
        return ProfileViewModel(
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
    
    public func makeSaleListViewModel() -> SaleListViewModel {
        return SaleListViewModel(
            repository: repositoryContainer.saleRepository
        )
    }
    
    public func makeCashflowTransactionListViewModel() -> CashflowTransactionListViewModel {
        return CashflowTransactionListViewModel(
            repository: repositoryContainer.cashflowRepository
        )
    }
    
    public func makeDailyCashflowViewModel() -> DailyCashFlowViewModel {
        return DailyCashFlowViewModel(
            repository: repositoryContainer.dailyCashflowRepository,
            cashflowRepository: repositoryContainer.cashflowRepository
        )
    }
    
    public func makeAddUpdateDailyCashflowViewModel(existingSummary: DailyCashflowSummary?, date: Date) -> AddUpdateDailyCashflowSummaryViewModel {
        return AddUpdateDailyCashflowSummaryViewModel(
            repository: repositoryContainer.dailyCashflowRepository,
            userRepository: repositoryContainer.userRepository,
            organizationRepository: repositoryContainer.organizationRepository,
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
