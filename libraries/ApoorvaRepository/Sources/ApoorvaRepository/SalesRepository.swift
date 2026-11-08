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
    func getSale(id: String) async throws -> Sale?
    func saveSale(sale: Sale) async throws
    func updateSale(_ sale: Sale) async throws
    func deleteSale(id: String) async throws // Hard delete
    func markAsDeleted(id: String) async throws  // Soft delete
    func confirmSale(_ sale: Sale, heldBillId: String?) async throws
    /// Marks a sale cancelled with a reason (soft status change, never deleted). Returns the updated sale.
    @discardableResult
    func cancelSale(id: String, reason: String, by staffId: String) async throws -> Sale?
    /// Saves an edited sale (lines, totals, payments) along with why it was edited.
    func editSale(_ sale: Sale, reason: String) async throws
    func sync(force: Bool) async throws
}


public final actor SaleRepository: SaleRepositoryProtocol {

    let storage: SaleStorageProtocol
    let service: SaleServiceProtocol
    let customerService: CustomerServiceProtocol
    let heldBillRepository: HeldBillRepositoryProtocol
    let userRepository: UserRepositoryProtocol
    let syncStorage: SyncStorage

    public init(storage: SaleStorageProtocol,
                service: SaleServiceProtocol,
                customerService: CustomerServiceProtocol,
                heldBillRepository: HeldBillRepositoryProtocol,
                userRepository: UserRepositoryProtocol,
                syncStorage: SyncStorage) {
        self.storage = storage
        self.service = service
        self.customerService = customerService
        self.heldBillRepository = heldBillRepository
        self.userRepository = userRepository
        self.syncStorage = syncStorage
    }

    public func getSales() async throws -> [Sale] {
        try await storage.getSales()
    }

    public func getSale(id: String) async throws -> Sale? {
        try await storage.getSale(id: id)
    }

    /// Writes the confirmed sale (local cache + Firestore), bumps the customer's running
    /// stats, and clears the held bill it was resumed from, if any. Not atomic — there's no
    /// Firestore batch primitive on `FirestoreStoring` yet — but each step is independently
    /// idempotent-safe to retry.
    public func confirmSale(_ sale: Sale, heldBillId: String?) async throws {
        try await storage.saveSale(sale: sale)

        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }

        try await service.addSale(sale, for: orgId)
        try await customerService.upsertCustomerAfterSale(
            phone: sale.customerPhone,
            name: sale.customerName,
            saleAmount: sale.netPayable,
            saleDate: sale.timestamp,
            for: orgId
        )

        if let heldBillId {
            try await heldBillRepository.deleteHeldBill(id: heldBillId)
        }
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

    @discardableResult
    public func cancelSale(id: String, reason: String, by staffId: String) async throws -> Sale? {
        guard var sale = try await storage.getSale(id: id), !sale.isCancelled else { return nil }
        let now = Date()
        sale.status = "Cancelled"
        sale.cancelReason = reason
        sale.cancelledBy = staffId
        sale.cancelledAt = now
        sale.updatedAt = now
        try await storage.updateSale(sale: sale)

        let user = try await userRepository.getCurrentUser()
        if let orgId = user.selectedOrganization?.orgId {
            try await service.updateSaleStatus(saleId: id, status: sale.status, reason: reason, by: staffId, at: now, for: orgId)
        }
        return sale
    }

    public func editSale(_ sale: Sale, reason: String) async throws {
        var edited = sale
        let now = Date()
        edited.editReason = reason
        edited.editedAt = now
        edited.updatedAt = now
        try await storage.updateSale(sale: edited)

        let user = try await userRepository.getCurrentUser()
        if let orgId = user.selectedOrganization?.orgId {
            try await service.updateSale(edited, for: orgId)
        }
    }
    
    public func sync(force: Bool) async throws {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }
        
        let sales: [Sale]
        
        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: Sale.table.name)
        if let lastUpdatedDate, !force {
            sales = try await service.getSales(since: SyncCursor.queryStart(from: lastUpdatedDate), for: orgId)
        } else {
            sales = try await service.getSales(for: orgId)
        }
        try await storage.saveSales(sales: sales)

        // New sales match on `timestamp`, edits/cancellations on `updatedAt` — track whichever is newest.
        guard let latest = SyncCursor.latest(sales.flatMap { [$0.timestamp, $0.updatedAt] }) else { return }
        try await syncStorage.updateSyncTimestamp(for: Sale.table.name, timestamp: latest.timeIntervalSince1970)
    }
}
