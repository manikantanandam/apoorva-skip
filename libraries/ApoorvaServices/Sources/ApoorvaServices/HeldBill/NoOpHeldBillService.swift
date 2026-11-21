//
//  NoOpHeldBillService.swift
//  ApoorvaServices
//
//  Used only by UI tests (`-UITesting`), where Firebase isn't configured: writes are dropped and
//  reads return nothing, so holding a bill works against local storage alone.
//

import Foundation
import ApoorvaModels

public final class NoOpHeldBillService: HeldBillServiceProtocol {
    public init() {}

    public func getHeldBills(for orgId: String) async throws -> [HeldBill] { [] }

    public func getHeldBills(since lastSync: Date, for orgId: String) async throws -> [HeldBill] { [] }

    public func addHeldBill(_ heldBill: HeldBill, for orgId: String) async throws {}

    public func updateHeldBill(_ heldBill: HeldBill, for orgId: String) async throws {}

    public func deleteHeldBill(id: String, for orgId: String) async throws {}
}
