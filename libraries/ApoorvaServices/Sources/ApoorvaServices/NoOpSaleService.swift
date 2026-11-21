//
//  NoOpSaleService.swift
//  ApoorvaServices
//
//  Used only by UI tests (`-UITesting`), where Firebase isn't configured: writes are dropped and
//  reads return nothing, so completing a sale works against local storage alone.
//

import Foundation
import ApoorvaModels

public final class NoOpSaleService: SaleServiceProtocol {
    public init() {}

    public func getSales(for orgId: String) async throws -> [Sale] { [] }

    public func getSales(since lastSync: Date, for orgId: String) async throws -> [Sale] { [] }

    public func addSale(_ sale: Sale, for orgId: String) async throws {}

    public func updateSaleStatus(saleId: String, status: String, reason: String, by staffId: String, at date: Date, for orgId: String) async throws {}

    public func updateSale(_ sale: Sale, for orgId: String) async throws {}
}
