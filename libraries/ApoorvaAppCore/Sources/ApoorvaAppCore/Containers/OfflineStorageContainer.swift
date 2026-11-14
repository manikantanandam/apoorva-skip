//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaOfflineStorage
import ApoorvaUtilities
import ApoorvaEnvironment
import ManiLogger

private let logger = AppLogger(category: .storage)

// In ApoorvaAppCore
@MainActor
public class OfflineStorageContainer {
    // Lazy initialization ensures these are only created when needed
//    public lazy var offlineStorage: OfflineStorageProtocol = ApoorvaDataStore()
//    public lazy var apiClient: ApiClientProtocol = ApoorvaNetworkClient()
    
    private let environment: AppEnvironment

    /// Each environment gets its own database file so data never mixes across backends.
    /// Production keeps the legacy name so existing installs retain their data.
    public var databasePath: String {
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let fileName = environment == .production ? "apoorva.sqlite" : environment.dbFileName()
        return "\(path)/\(fileName)"
    }

    public lazy var skipSqlDatabase: SkipSqlDatabase = {
        do {
            let dbPath = databasePath

            logger.debug("DB Path: \(dbPath)")

            // The Documents directory may not exist yet (e.g. headless CI), which makes SQLite fail with CANTOPEN.
            try FileManager.default.createDirectory(
                atPath: (dbPath as NSString).deletingLastPathComponent,
                withIntermediateDirectories: true
            )

            // Opening the database also runs any pending schema migrations.
            return try SkipSqlDatabase(filepath: dbPath)
        } catch {
            fatalError("Failed to initialize local database: \(error)")
        }
    }()
    
    public lazy var userDefaultsStorage: UserDefaultsStorageProtocol = UserDefaultsStorage()
    
    public lazy var inventoryItemsLocalStorage: InventoryItemLocalStorageProtocol = InventoryItemLocalStorage(
        database: skipSqlDatabase
    )
    
    
    public lazy var customersLocalStorage: CustomerStorageProtocol = CustomerLocalStorage(
        database: skipSqlDatabase
    )
    
    public lazy var salesLocalStorage: SaleStorageProtocol = SaleLocalStorage(
        database: skipSqlDatabase
    )
    
    public lazy var cashflowLocalStorage: CashflowTransactionStorageProtocol = CashflowTransactionLocalStorage(
        database: skipSqlDatabase
    )
    
    public lazy var dailyCashflowStorage: DailyCashflowSummaryStorageProtocol = DailyCashflowSummaryLocalStorage(
        database: skipSqlDatabase
    )
    
    public lazy var organizationStorage: OrganizationStorageProtocol = OrganizationLocalStorage(
        database: skipSqlDatabase
    )

    public lazy var heldBillsLocalStorage: HeldBillStorageProtocol = HeldBillLocalStorage(
        database: skipSqlDatabase
    )

    public lazy var syncStorage: SyncStorage = SyncStorage(db: skipSqlDatabase)
    
    public init(environment: AppEnvironment = .production) {
        self.environment = environment
    }
}
