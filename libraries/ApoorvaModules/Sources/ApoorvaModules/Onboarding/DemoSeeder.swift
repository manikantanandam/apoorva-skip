//
//  DemoSeeder.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

/// Fills the (empty, signed-out) local database with a sample shop for the demo (design 02).
/// The demo user has no org, so repositories never write to Firestore.
public struct DemoSeeder: Sendable {
    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let customerRepository: CustomerRepositoryProtocol
    private let saleRepository: SaleRepositoryProtocol

    public init(inventoryRepository: InventoryItemRepositoryProtocol,
                customerRepository: CustomerRepositoryProtocol,
                saleRepository: SaleRepositoryProtocol) {
        self.inventoryRepository = inventoryRepository
        self.customerRepository = customerRepository
        self.saleRepository = saleRepository
    }

    public static func shopName(for vertical: Vertical) -> String {
        switch vertical {
        case .kirana: "Sri Lakshmi Stores"
        case .fancy: "Glitz Gifts & Fancy"
        case .jewellery: "Swarna One Gram"
        case .parlour: "Glow Beauty Parlour"
        }
    }

    public static func settings(for vertical: Vertical) -> OrgSettings {
        var settings = OrgSettings()
        settings.profile = OrgSettings.Profile(shopName: shopName(for: vertical), phone: "98480 12345",
                                               address: "Ameerpet, Hyderabad", billPrefix: "D-", vertical: vertical,
                                               setupCompletedAt: Date())
        settings.flags.org = vertical.defaultFlags
        settings.plan = OrgSettings.Plan(tier: .pro)
        return settings
    }

    public func seed(_ vertical: Vertical) async throws {
        let items = Self.items(for: vertical)
        for item in items {
            try await inventoryRepository.saveInventoryItem(item: item)
        }
        let customers = [("Ravi Kumar", "9848012345", 0.0), ("Meena S", "9123456780", 1120), ("Sneha P", "9988776655", 0)]
        let now = Date()
        for (name, phone, due) in customers {
            try await customerRepository.saveCustomer(customer: Customer(
                name: name, phone: phone, createdAt: now.addingTimeInterval(-86_400 * 60).timeIntervalSince1970,
                lastPurchaseDate: now.timeIntervalSince1970, totalSales: 4, totalAmountSpent: 2_400,
                updatedAt: now.timeIntervalSince1970, isDeleted: false, dueBalance: due))
        }
        for (index, item) in items.prefix(6).enumerated() {
            let price = item.sellPrice ?? 100
            let customer = customers[index % customers.count]
            let sale = Sale(id: "demo-\(index)", staffId: "demo", customerPhone: customer.1, customerName: customer.0,
                            items: [SaleItem(categoryId: item.id, categoryName: item.name, qty: 1 + index % 3,
                                             stickerPrice: price, finalPrice: price, discountType: .percentage)],
                            subtotal: price * Double(1 + index % 3), overallDiscountPercent: 0, overallDiscountAmount: 0,
                            roundOff: 0, netPayable: price * Double(1 + index % 3),
                            payments: [index % 2 == 0 ? .cash : .upi: price * Double(1 + index % 3)],
                            timestamp: now.addingTimeInterval(Double(-index) * 1_800), source: "POS",
                            status: "Completed", whatsappStatus: "unsent", billNumber: "D-\(1040 + index)")
            try await saleRepository.saveSale(sale: sale)
        }
    }

    static func items(for vertical: Vertical) -> [InventoryItem] {
        let rows: [(String, Double, Int, Bool)]
        switch vertical {
        case .kirana:
            rows = [("Toor Dal 1kg", 160, 24, true), ("Sona Masoori Rice 5kg", 340, 12, true), ("Sunflower Oil 1L", 145, 3, true),
                    ("Sugar 1kg", 46, 40, false), ("Tea Powder 250g", 120, 18, true), ("Onions (kg)", 35, 50, true)]
        case .fancy:
            rows = [("Glass Bangles", 120, 40, true), ("Teddy 12in", 499, 3, true), ("Gift Wrap Roll", 30, 5, true),
                    ("Photo Frame", 250, 14, false), ("Hair Clips Set", 80, 30, true), ("Key Chain", 60, 22, false)]
        case .jewellery:
            rows = [("Lakshmi Haram", 2_400, 6, true), ("Jhumka Gold", 650, 12, true), ("Kemp Bangles", 1_200, 8, true),
                    ("Mango Mala", 1_850, 4, false), ("Nose Pin", 180, 30, true), ("Ear Chain", 320, 15, false)]
        case .parlour:
            rows = [("Haircut", 250, 999, true), ("Facial", 800, 999, true), ("Threading", 50, 999, true),
                    ("Hair Spa", 1_200, 999, true), ("Manicure", 450, 999, false), ("Bridal Makeup", 6_000, 999, false)]
        }
        return rows.enumerated().map { index, row in
            InventoryItem(id: "demo-item-\(index)", name: row.0, currentStock: row.2, billMachineNumber: index + 1,
                          isHotkey: row.3, sellPrice: row.1, costPrice: row.1 * 0.7, unit: vertical == .kirana && index == 5 ? "kg" : "pc",
                          designCode: vertical == .jewellery ? "DS-\(100 + index)" : nil)
        }
    }
}
