//
//  CustomerStorageProtocol.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import ApoorvaModels

public protocol SaleStorageProtocol: Sendable {
    
    func getSales() throws -> [Sale]
    
    func saveSales(sales: [Sale]) throws

    func saveSale(sale: Sale) throws
        
    func getSale(id: String) throws -> Sale?

    func updateSale(sale: Sale) throws
    
    func deleteSale(id: String) throws // Hard delete
    
    func markAsDeleted(id: String) throws  // Soft delete
}
