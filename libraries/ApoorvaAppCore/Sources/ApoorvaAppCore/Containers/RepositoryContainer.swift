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
        authService: servicesContainer.authService
    )
}
