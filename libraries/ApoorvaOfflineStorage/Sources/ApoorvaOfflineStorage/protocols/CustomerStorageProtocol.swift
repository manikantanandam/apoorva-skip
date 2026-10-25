//
//  CustomerStorageProtocol.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels

public protocol CustomerStorageProtocol: Sendable {
    
    func getCustomers() async throws -> [Customer]
    
    func saveCustomers(customers: [Customer]) async throws

    func saveCustomer(customer: Customer) async throws
    
    func getCustomer(phoneNumber: String) async throws -> Customer?
    
    func getCustomer(name: String) async throws -> Customer?

    
    func updateCustomer(customer: Customer) async throws
    
    func deleteCustomer(phoneNumber: String) async throws // Hard delete
    
    func markAsDeleted(id: String) async throws  // Soft delete
}
