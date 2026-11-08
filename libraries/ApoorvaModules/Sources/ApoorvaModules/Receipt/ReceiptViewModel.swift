//
//  ReceiptViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class ReceiptViewModel {

    public let saleId: String
    public var sale: Sale?

    private let saleRepository: SaleRepositoryProtocol

    public init(saleId: String, saleRepository: SaleRepositoryProtocol) {
        self.saleId = saleId
        self.saleRepository = saleRepository
    }

    public func load() async {
        do {
            sale = try await saleRepository.getSale(id: saleId)
        } catch {
            print("Failed to load sale \(saleId): \(error.localizedDescription)")
        }
    }
}
