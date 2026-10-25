//
//  CustomerStorageProtocol.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import ApoorvaModels

public protocol SaleStorageProtocol: Sendable {
    
    func getSales() async throws -> [Sale]
    
    func saveSales(sales: [Sale]) async throws

    func saveSale(sale: Sale) async throws
        
    func getSale(id: String) async throws -> Sale?

    func updateSale(sale: Sale) async throws
    
    func deleteSale(id: String) async throws // Hard delete
    
    func markAsDeleted(id: String) async throws  // Soft delete
}
