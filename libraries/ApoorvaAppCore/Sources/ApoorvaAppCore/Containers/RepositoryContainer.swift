//
//  RepositoryContainer.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaServices
import ApoorvaRepository

// In ApoorvaAppCore
@MainActor
public class RepositoryContainer {
    private let servicesContainer: ServicesContainer
    private let offlineStorageContainer: OfflineStorageContainer
    
    public init(servicesContainer: ServicesContainer,
                offlineStorageContainer: OfflineStorageContainer) {
        self.servicesContainer = servicesContainer
        self.offlineStorageContainer = offlineStorageContainer
    }
    
    public lazy var userRepository = UserRepository(
        userDefaults: offlineStorageContainer.userDefaultsStorage,
        authService: servicesContainer.authService,
        userService: servicesContainer.userService
    )
    
    public lazy var inventoryRepository: InventoryItemRepositoryProtocol = InventoryItemRepository(
        storage: offlineStorageContainer.inventoryItemsLocalStorage,
        service: servicesContainer.inventoryService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )
    
    public lazy var customerRepository: CustomerRepositoryProtocol = CustomerRepository(
        storage: offlineStorageContainer.customersLocalStorage,
        service: servicesContainer.customerService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )
    
    public lazy var saleRepository: SaleRepositoryProtocol = SaleRepository(
        storage: offlineStorageContainer.salesLocalStorage,
        service: servicesContainer.saleService,
        userRepository: userRepository,
        syncStorage: offlineStorageContainer.syncStorage
    )
}
