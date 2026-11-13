//
//  HeldBillsViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository
import ManiLogger

private let logger = AppLogger(category: .ui)

@MainActor
@Observable
public class HeldBillsViewModel {

    public var heldBills: [HeldBill] = []

    private let repository: HeldBillRepositoryProtocol

    public init(repository: HeldBillRepositoryProtocol) {
        self.repository = repository
    }

    public func prepareData() async {
        do {
            self.heldBills = try await repository.getHeldBills().sorted(by: >)
            try await repository.sync(force: false)
            self.heldBills = try await repository.getHeldBills().sorted(by: >)
        } catch {
            logger.error("Held bills failed to load\(error.localizedDescription)")
        }
    }

    public func delete(_ bill: HeldBill) async {
        do {
            try await repository.deleteHeldBill(id: bill.id)
            heldBills.removeAll { $0.id == bill.id }
        } catch {
            logger.error("Failed to delete held bill\(error.localizedDescription)")
        }
    }
}
