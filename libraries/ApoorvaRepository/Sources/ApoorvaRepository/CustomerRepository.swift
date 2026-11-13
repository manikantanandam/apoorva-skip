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
import ApoorvaLogging

private let logger = AppLogger(category: .sync)

public protocol CustomerRepositoryProtocol: Sendable {
    func getCustomers() async throws -> [Customer]
    func getCustomer(phone: String) async throws -> Customer?
    func saveCustomer(customer: Customer) async throws
    func updateCustomer(_ customer: Customer) async throws
    func deleteCustomer(phoneNumber: String) async throws // Hard delete
    func markAsDeleted(id: String) async throws  // Soft delete
    func sync(force: Bool) async throws
}


public extension CustomerRepositoryProtocol {
    func getCustomer(phone: String) async throws -> Customer? {
        try await getCustomers().first { $0.phone == phone }
    }
}

public final actor CustomerRepository: CustomerRepositoryProtocol {

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
        try await storage.getCustomers()
    }
    
    public func saveCustomer(customer: Customer) async throws {
        try await storage.saveCustomer(customer: customer)
        try await pushRemote(customer)
    }

    public func updateCustomer(_ customer: Customer) async throws {
        try await storage.updateCustomer(customer: customer)
        try await pushRemote(customer)
    }

    public func getCustomer(phone: String) async throws -> Customer? {
        try await storage.getCustomer(phoneNumber: phone)
    }

    private func pushRemote(_ customer: Customer) async throws {
        guard let orgId = try? await userRepository.getCurrentUser().selectedOrganization?.orgId else { return }
        try service.upsertCustomer(customer, for: orgId)
    }
    
    public func deleteCustomer(phoneNumber: String) async throws {
        try await storage.deleteCustomer(phoneNumber: phoneNumber)
    }
    
    public func markAsDeleted(id: String) async throws {
        try await storage.markAsDeleted(id: id)
    }
    
    public func sync(force: Bool) async throws {
        logger.info("Started Customer sync")
        let user = try await userRepository.getCurrentUser()
        logger.debug("Received user")

        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }
        
        let customers: [Customer]
        
        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: Customer.table.name)
        logger.debug("Last updated date \(lastUpdatedDate)")
        
        if let lastUpdatedDate, !force {
            logger.debug("Fetching customers since\(Date(timeIntervalSince1970: lastUpdatedDate)) for \(orgId)")
            customers = try await service.getCustomers(since: SyncCursor.queryStart(from: lastUpdatedDate), for: orgId)
            logger.debug("Received customers")
        } else {
            logger.debug("Fetching all customers for \(orgId)")
            customers = try await service.getCustomers(for: orgId)
        }
        logger.debug("Saving customers")
        try await storage.saveCustomers(customers: customers)
        // The query matches on updatedAt OR lastPurchaseDate, so the cursor tracks the newest of both.
        let dates = customers.flatMap { customer in
            [customer.updatedAt, customer.lastPurchaseDate].map { $0.map(Date.init(timeIntervalSince1970:)) }
        }
        guard let latest = SyncCursor.latest(dates) else { return }
        try await syncStorage.updateSyncTimestamp(for: Customer.table.name, timestamp: latest.timeIntervalSince1970)
    }
}
