//
//  HeldBillRepository.swift
//  ApoorvaRepository
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaOfflineStorage
import ApoorvaModels
import ApoorvaServices

public protocol HeldBillRepositoryProtocol: Sendable {
    func getHeldBills() async throws -> [HeldBill]
    func saveHeldBill(_ heldBill: HeldBill) async throws
    func updateHeldBill(_ heldBill: HeldBill) async throws
    func deleteHeldBill(id: String) async throws
    func markAsDeleted(id: String) async throws
    func sync(force: Bool) async throws
}


public final actor HeldBillRepository: HeldBillRepositoryProtocol {

    let storage: HeldBillStorageProtocol
    let service: HeldBillServiceProtocol
    let userRepository: UserRepositoryProtocol
    let syncStorage: SyncStorage

    public init(storage: HeldBillStorageProtocol,
                service: HeldBillServiceProtocol,
                userRepository: UserRepositoryProtocol,
                syncStorage: SyncStorage) {
        self.storage = storage
        self.service = service
        self.userRepository = userRepository
        self.syncStorage = syncStorage
    }

    public func getHeldBills() async throws -> [HeldBill] {
        try await storage.getHeldBills()
    }

    public func saveHeldBill(_ heldBill: HeldBill) async throws {
        try await storage.saveHeldBill(heldBill: heldBill)
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }
        try await service.addHeldBill(heldBill, for: orgId)
    }

    public func updateHeldBill(_ heldBill: HeldBill) async throws {
        try await storage.updateHeldBill(heldBill: heldBill)
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }
        try await service.updateHeldBill(heldBill, for: orgId)
    }

    public func deleteHeldBill(id: String) async throws {
        try await storage.markAsDeleted(id: id)
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else { return }
        try await service.deleteHeldBill(id: id, for: orgId)
    }

    public func markAsDeleted(id: String) async throws {
        try await storage.markAsDeleted(id: id)
    }

    public func sync(force: Bool) async throws {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else {
            return
        }

        let heldBills: [HeldBill]

        let lastUpdatedDate = try? await syncStorage.getLastSyncTimestamp(for: HeldBill.table.name)
        if let lastUpdatedDate, !force {
            heldBills = try await service.getHeldBills(since: Date(timeIntervalSince1970: lastUpdatedDate), for: orgId)
        } else {
            heldBills = try await service.getHeldBills(for: orgId)
        }
        try await storage.saveHeldBills(heldBills: heldBills)

        guard let heldBillWithMaxDate = heldBills.heldBillWithMaxDate,
              let lastUpdatedDate = heldBillWithMaxDate.updatedAt else { return }

        try await syncStorage.updateSyncTimestamp(for: HeldBill.table.name, timestamp: lastUpdatedDate.timeIntervalSince1970)
    }
}


private extension Array where Element == HeldBill {
    var heldBillWithMaxDate: HeldBill? {
        self.max(by: {
            guard
                let lhs = $0.updatedAt,
                let rhs = $1.updatedAt
            else { return false }
            return lhs < rhs
        })
    }
}
