//
//  NoOpCustomerService.swift
//  ApoorvaServices
//
//  Used only by UI tests (`-UITesting`), where Firebase isn't configured: writes are dropped and
//  reads return nothing, so the repository keeps working against local storage alone.
//

import Foundation
import ApoorvaModels

public final class NoOpCustomerService: CustomerServiceProtocol {
    public init() {}

    public func getCustomers(for orgId: String) async throws -> [Customer] { [] }

    public func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer] { [] }

    public func upsertCustomerAfterSale(phone: String, name: String, saleAmount: Double, saleDate: Date, for orgId: String) async throws {}

    public func upsertCustomer(_ customer: Customer, for orgId: String) throws {}
}
