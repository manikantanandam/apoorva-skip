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
    
    public lazy var skipSqlDatabase: SkipSqlDatabase = {
        do {
            // Get the standard documents directory path
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            let dbPath = "\(path)/apoorva.sqlite"
            
            print("DB Path: \(path)")
            
            // This will also trigger try createTables() as defined in SkipSqlDatabase
            return try SkipSqlDatabase(filepath: dbPath)
        } catch {
            fatalError("Failed to initialize local database: \(error)")
        }
    }()
    
    public lazy var userDefaultsStorage: UserDefaultsStorageProtocol = UserDefaultsStorage()
    
    public lazy var inventoryItemsLocalStorage: InventoryItemLocalStorageProtocol = InventoryItemLocalStorage(
        database: skipSqlDatabase
    )
    
    public lazy var syncStorage: SyncStorage = SyncStorage(db: skipSqlDatabase)
    
    public init() {}
}
