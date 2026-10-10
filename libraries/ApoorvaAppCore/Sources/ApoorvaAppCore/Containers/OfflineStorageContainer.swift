//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaOfflineStorage

// In ApoorvaAppCore
@MainActor
public class OfflineStorageContainer {
    // Lazy initialization ensures these are only created when needed
//    public lazy var offlineStorage: OfflineStorageProtocol = ApoorvaDataStore()
//    public lazy var apiClient: ApiClientProtocol = ApoorvaNetworkClient()
    
    public lazy var userDefaultsStorage: UserDefaultsStorageProtocol = UserDefaultsStorage()
    
    public init() {}
}
