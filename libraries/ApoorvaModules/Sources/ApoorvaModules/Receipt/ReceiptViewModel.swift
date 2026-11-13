//
//  ReceiptViewModel.swift
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
public class ReceiptViewModel {

    public let saleId: String
    public var sale: Sale?
    /// Cash handed over at checkout, for "Change returned".
    public var cashReceived: Double?

    private let saleRepository: SaleRepositoryProtocol
    private let session: AppSession?

    public init(saleId: String, saleRepository: SaleRepositoryProtocol, session: AppSession? = nil, cashReceived: Double? = nil) {
        self.saleId = saleId
        self.saleRepository = saleRepository
        self.session = session
        self.cashReceived = cashReceived
    }

    public func load() async {
        do {
            sale = try await saleRepository.getSale(id: saleId)
        } catch {
            logger.error("Failed to load sale\(saleId): \(error.localizedDescription)")
        }
    }

    public var shopName: String { session?.displayShopName ?? "" }

    public var changeReturned: Double {
        guard let sale, let cashReceived else { return 0 }
        return max(0, cashReceived - (sale.payments[.cash] ?? 0))
    }

    public var paidBy: String {
        guard let sale else { return "" }
        return sale.payments.filter { $0.value != 0 }.keys.map(\.title).sorted().joined(separator: " + ")
    }

    private var upiLink: String? {
        guard let sale, let upiId = session?.settings.payments.upiId, !upiId.isEmpty, sale.isDue else { return nil }
        return UPILink.pay(upiId: upiId, payee: shopName, amount: sale.dueAmount, note: "Bill \(sale.displayNumber)")
    }

    public var shareText: String {
        guard let sale else { return "" }
        return ReceiptFormatter.shareText(for: sale, shopName: shopName, upiLink: upiLink)
    }

    public var thermalLines: [String] {
        guard let sale else { return [] }
        let settings = session?.settings ?? OrgSettings()
        return ReceiptFormatter.thermalLines(for: sale, settings: settings, shopName: shopName.isEmpty ? "Apoorva" : shopName,
                                             columns: settings.receipt.paperSize == .mm80 ? 48 : 32)
    }

    /// wa.me link to the customer (or an open share when there's no number).
    public var whatsAppURL: URL? {
        let digits = (sale?.customerPhone ?? "").filter(\.isNumber)
        let number = digits.count == 10 ? "91" + digits : digits
        var components = URLComponents(string: "https://wa.me/\(number)")
        components?.queryItems = [URLQueryItem(name: "text", value: shareText)]
        return components?.url
    }

    public var smsURL: URL? {
        let digits = (sale?.customerPhone ?? "").filter(\.isNumber)
        guard !digits.isEmpty else { return nil }
        var components = URLComponents(string: "sms:\(digits)")
        components?.queryItems = [URLQueryItem(name: "body", value: shareText)]
        return components?.url
    }
}
