//
//  File.swift
//  ApoorvaRepository
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaOfflineStorage
import ApoorvaModels
import ApoorvaServices

public protocol SaleRepositoryProtocol: Sendable {
    func getSales() async throws -> [Sale]
    func saveSale(sale: Sale) async throws
    func updateSale(_ sale: Sale) async throws
    func deleteSale(id: String) async throws // Hard delete
    func markAsDeleted(id: String) async throws  // Soft delete
    func sync(force: Bool) async throws
}


public final class SaleRepository: SaleRepositoryProtocol {

    let storage: SaleStorageProtocol
    let service: SaleServiceProtocol
    let userRepository: UserRepositoryProtocol
    let syncStorage: SyncStorage
    
    public init(storage: SaleStorageProtocol,
                service: SaleServiceProtocol,
                userRepository: UserRepositoryProtocol,
                syncStorage: SyncStorage) {
        self.storage = storage
        self.service = service
        self.userRepository = userRepository
        self.syncStorage = syncStorage
    }
    
    public func getSales() async throws -> [Sale] {
        try await storage.getSales()
    }
    
    public func saveSale(sale: Sale) async throws {
        try await storage.saveSale(sale: sale)
    }
    
    public func updateSale(_ sale: Sale) async throws {
        try await storage.updateSale(sale: sale)
    }
    
    public func deleteSale(id: String) async throws {
        try await storage.deleteSale(id: id)
    }
    
    public func markAsDeleted(id: String) async throws {
        try await storage.markAsDeleted(id: id)
    }
    
    public func sync(force: Bool) async throws {
        print("Started sync")
        let user = try await userRepository.getCurrentUser()
        print("Received used")

        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }
        
        let sales: [Sale]
        
        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: Sale.table.name)
        print("Last updted date \(lastUpdatedDate)")
        
        if let lastUpdatedDate, !force {
            print("Fetching inventory sales since \(Date(timeIntervalSince1970: lastUpdatedDate)) for \(orgId)")
            sales = try await service.getSales(since: Date(timeIntervalSince1970: lastUpdatedDate), for: orgId)
            print("Received sales")
        } else {
            print("Fetch all inventiry sales \(orgId)")
            sales = try await service.getSales(for: orgId)
        }
        print("Saving sales")
        try await storage.saveSales(sales: sales)
        
        guard
            let saleWithMinUpdatedAt = sales.saleWithMaxDate
        else { return }
        
        print("sale with min update \(saleWithMinUpdatedAt)")
        
        guard let lastUpdatedDate = saleWithMinUpdatedAt.updatedAt else { return }
        print("saving lastUpdatedDate \(lastUpdatedDate)")

        try await syncStorage.updateSyncTimestamp(for: Sale.table.name, timestamp: lastUpdatedDate.timeIntervalSince1970)
    }
}


private extension Array where Element == Sale {
    var saleWithMaxDate: Sale? {
        self.max(by: {
            guard
                let lastUpdatedDateItem1 = $0.updatedAt,
                let lastUpdatedDateItem2 = $1.updatedAt
            else { return false }
            
            return lastUpdatedDateItem1 > lastUpdatedDateItem2
        })
    }
}
