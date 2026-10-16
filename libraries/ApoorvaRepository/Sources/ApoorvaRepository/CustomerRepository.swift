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

public protocol CustomerRepositoryProtocol: Sendable {
    func getCustomers() async throws -> [Customer]
    func saveCustomer(customer: Customer) async throws
    func updateCustomer(_ customer: Customer) async throws
    func deleteCustomer(phoneNumber: String) async throws // Hard delete
    func markAsDeleted(id: String) async throws  // Soft delete
    func sync(force: Bool) async throws
}


public final class CustomerRepository: CustomerRepositoryProtocol {

    let storage: CustomerStorageProtocol
    let service: CustomerServiceProtocol
    let userRepository: UserRepositoryProtocol
    let syncStorage: SyncStorage
    
    public init(storage: CustomerStorageProtocol,
                service: CustomerServiceProtocol,
                userRepository: UserRepositoryProtocol,
                syncStorage: SyncStorage) {
        self.storage = storage
        self.service = service
        self.userRepository = userRepository
        self.syncStorage = syncStorage
    }
    
    public func getCustomers() async throws -> [Customer] {
        try storage.getCustomers()
    }
    
    public func saveCustomer(customer: Customer) async throws {
        try storage.saveCustomer(customer: customer)
    }
    
    public func updateCustomer(_ customer: Customer) async throws {
        try storage.updateCustomer(customer: customer)
    }
    
    public func deleteCustomer(phoneNumber: String) async throws {
        try storage.deleteCustomer(phoneNumber: phoneNumber)
    }
    
    public func markAsDeleted(id: String) async throws {
        try storage.markAsDeleted(id: id)
    }
    
    public func sync(force: Bool) async throws {
        print("Started sync")
        let user = try await userRepository.getCurrentUser()
        print("Received used")

        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }
        
        let customers: [Customer]
        
        let lastUpdatedDate = try? syncStorage.getLastSyncTimestamp(for: Customer.table.name)
        print("Last updted date \(lastUpdatedDate)")
        
        if let lastUpdatedDate, !force {
            print("Fetching inventory customers since \(Date(timeIntervalSince1970: lastUpdatedDate)) for \(orgId)")
            customers = try await service.getCustomers(since: Date(timeIntervalSince1970: lastUpdatedDate), for: orgId)
            print("Received customers")
        } else {
            print("Fetch all customers \(orgId)")
            customers = try await service.getCustomers(for: orgId)
        }
        print("Saving inventory customers")
        try storage.saveCustomers(customers: customers)
        guard
            let customerWithMinUpdatedAt = customers.customerWithMaxDate
        else { return }
        
        print("customer with min update \(customerWithMinUpdatedAt)")
        
        guard let lastUpdatedDate = customerWithMinUpdatedAt.updatedAt else { return }
        print("saving lastUpdatedDate \(lastUpdatedDate)")

        try syncStorage.updateSyncTimestamp(for: Customer.table.name, timestamp: lastUpdatedDate)
    }
}


private extension Array where Element == Customer {
    var customerWithMaxDate: Customer? {
        self.max(by: {
            guard
                let lastUpdatedDateItem1 = $0.lastPurchaseDate,
                let lastUpdatedDateItem2 = $1.lastPurchaseDate
            else { return false }
            
            return lastUpdatedDateItem1 > lastUpdatedDateItem2
        })
    }
}
