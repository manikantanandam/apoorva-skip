//
//  CustomerStorageProtocol.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels

public protocol CustomerStorageProtocol: Sendable {
    
    func getCustomers() throws -> [Customer]
    
    func saveCustomers(customers: [Customer]) throws

    func saveCustomer(customer: Customer) throws
    
    func getCustomer(phoneNumber: String) throws -> Customer?
    
    func getCustomer(name: String) throws -> Customer?

    
    func updateCustomer(customer: Customer) throws
    
    func deleteCustomer(phoneNumber: String) throws // Hard delete
    
    func markAsDeleted(id: String) throws  // Soft delete
}
