//
//  HeldBillStorageProtocol.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaModels

public protocol HeldBillStorageProtocol: Sendable {

    func getHeldBills() async throws -> [HeldBill]

    func saveHeldBills(heldBills: [HeldBill]) async throws

    func saveHeldBill(heldBill: HeldBill) async throws

    func getHeldBill(id: String) async throws -> HeldBill?

    func updateHeldBill(heldBill: HeldBill) async throws

    func deleteHeldBill(id: String) async throws // Hard delete

    func markAsDeleted(id: String) async throws  // Soft delete
}
