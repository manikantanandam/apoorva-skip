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
        return ProfileViewModel(userRepository: repositoryContainer.userRepository)
    }
}
