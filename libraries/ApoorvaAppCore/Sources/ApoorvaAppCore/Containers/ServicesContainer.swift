//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaServices

// In ApoorvaAppCore
@MainActor
public class ServicesContainer {
    // Lazy initialization ensures these are only created when needed
//    public lazy var offlineStorage: OfflineStorageProtocol = ApoorvaDataStore()
//    public lazy var apiClient: ApiClientProtocol = ApoorvaNetworkClient()
    
    public lazy var authService: AuthServicing = AuthService()
    
    public lazy var userService: UserServiceProtocol = UserService(authService: authService)
    
    public lazy var inventoryService: InventoryItemServiceProtocol = InventoryItemService()
    
    public lazy var customerService: CustomerServiceProtocol = CustomerService()
    
    public lazy var saleService: SaleServiceProtocol = SaleService()
    
    public lazy var cashflowService: CashflowTransactionServiceProtocol = CashflowTransactionService()
    
    public lazy var dailyCashflowService: DailyCashflowSummaryServiceProtocol = DailyCashflowSummaryService()
    
    public lazy var organizationService: OrganizationServiceProtocol = OrganizationService()
    
    
    public init() {}
}
