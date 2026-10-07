//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation
import ApoorvaUI
import ApoorvaServices

// In ApoorvaPOS Module
@MainActor
public class LoginContainer {
    private let core: CoreContainer
    
//    // Feature-specific repositories (lazy so they don't consume memory until POS is opened)
//    private lazy var posRepository: PosRepositoryProtocol = {
//        PosRepository(api: core.apiClient, storage: core.offlineStorage)
//    }()
    
    public init(core: CoreContainer) {
        self.core = core
    }
    
    public func makeLoginViewModel() -> LoginViewModel {
        return LoginViewModel(
            authService: core.authService
        )
    }
}
