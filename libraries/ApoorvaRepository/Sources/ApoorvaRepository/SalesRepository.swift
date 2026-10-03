import Foundation
import ApoorvaOfflineStorage
import ApoorvaServices
import ApoorvaModels

public typealias Category = ApoorvaModels.Category

public final class SalesRepository {
    public let localDB: AppDatabase
    private let remoteAPI: FirestoreSyncService
    
    public init(databaseURL: URL) throws {
        self.localDB = try AppDatabase(databaseURL: databaseURL)
        self.remoteAPI = FirestoreSyncService()
    }
    
    // MARK: - Orchestration Logic
    
    // Pass the orgId into the sync method
    // MARK: - Orchestration Logic
        public func performFullSync(for orgId: String) async throws {
            
            // 👉 THE FIX: We removed 'let syncTimestamp = Date()'
            // We will only advance cursors based on actual received data.
            
            // 1. Sync Sales
            let lastSaleSync = try await localDB.getLastSyncDate(for: "sales_\(orgId)")
            let modifiedSales = try await remoteAPI.fetchSaleDeltas(for: orgId, since: lastSaleSync)
            
            if !modifiedSales.isEmpty {
                try await localDB.upsertSales(modifiedSales)
                
                // Extract the newest timestamp from the payload to use as our next cursor
                if let latestSaleDate = modifiedSales.map({ $0.timestamp }).max() {
                    try await localDB.updateSyncDate(latestSaleDate, for: "sales_\(orgId)")
                }
            }
            // Notice: If modifiedSales is empty, we do NOT update the sync date!
            
            
            // 2. Sync Customers
            let lastCustomerSync = try await localDB.getLastSyncDate(for: "customers_\(orgId)")
            let modifiedCustomers = try await remoteAPI.fetchCustomerDeltas(for: orgId, since: lastCustomerSync)
            if !modifiedCustomers.isEmpty {
                try await localDB.upsertCustomers(modifiedCustomers)
                // (Assuming your Customer model uses 'updatedAt'. Adjust if needed)
                // if let latestCustomerDate = modifiedCustomers.map({ $0.updatedAt }).max() {
                //     try await localDB.updateSyncDate(latestCustomerDate, for: "customers_\(orgId)")
                // }
                // If you can't easily map the date, the safest fallback is just skipping the cursor
                // advancement until you implement it, rather than using local Date().
            }
            
            
            // 3. Sync Inventory
            let lastInventorySync = try await localDB.getLastSyncDate(for: "inventory_\(orgId)")
            let modifiedInventory = try await remoteAPI.fetchInventoryDeltas(for: orgId, since: lastInventorySync)
            if !modifiedInventory.isEmpty {
                try await localDB.upsertInventory(modifiedInventory)
            }
            
            
            // 4. Sync Categories
            print("🔄 Syncing Categories...")
            let lastCatSync = try await localDB.getLastSyncDate(for: "categories_\(orgId)")
            let modifiedCategories = try await remoteAPI.fetchCategoryDeltas(for: orgId, since: lastCatSync)
            if !modifiedCategories.isEmpty {
                try await localDB.upsertCategories(modifiedCategories)
            }
            
            print("✅ Full Delta Sync Completed for \(orgId)!")
        }
    
    // MARK: - Data Reads
    
    public func getTodayRevenue() async throws -> Double {
        return try await localDB.getTotalRevenueForToday()
    }
    
    public func getAllSales() async throws -> [Sale] {
            return try await localDB.getAllSales()
        }
    
    public func getAllCustomers() async throws -> [Customer] {
            return try await localDB.getAllCustomers()
        }
        
        public func getAllCategories() async throws -> [Category] {
            return try await localDB.getAllCategories()
        }
}
