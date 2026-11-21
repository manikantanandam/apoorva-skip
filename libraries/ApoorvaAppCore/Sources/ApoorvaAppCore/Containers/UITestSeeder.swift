//
//  UITestSeeder.swift
//  ApoorvaAppCore
//
//  Fills the local DB with a sample shop and signs a fake owner in, so UI tests start on Home
//  (`-UITesting -UITestingSeed fancy|kirana`). Compiled out of release builds.
//

#if DEBUG
import Foundation
import ApoorvaModels
import ApoorvaServices
import ManiLogger

private let logger = AppLogger(category: .app)

@MainActor
struct UITestSeeder {
    static let orgId = "uitest-org"
    static let userId = "uitest-uid"

    let container: AppContainer

    /// Seeds while the session has no org (repositories then write local-only), then publishes the owner.
    func run(verticalName: String) async {
        let vertical = Vertical(rawValue: verticalName) ?? .fancy
        let repositories = container.repositoryContainer
        let fakeUserService = container.servicesContainer.userService as? FakeUserService
        fakeUserService?.prepare(AppUser(id: Self.userId, name: "UI Test owner", email: "uitest@apoorva.app", role: .admin,
                                         status: "active", assignedOrgs: [], createdAt: Date()))
        let clock = ContinuousClock()
        let start = clock.now
        do {
            try await repositories.clearLocalData()
            logger.info("UI test seed: cleared local data in \(clock.now - start)")
            try await repositories.settingsRepository.save(Self.settings(for: vertical))
            for item in Self.items(for: vertical) {
                try await repositories.inventoryRepository.saveInventoryItem(item: item)
            }
            for customer in Self.customers() {
                try await repositories.customerRepository.saveCustomer(customer: customer)
            }
            for sale in Self.sales(for: vertical) {
                try await repositories.saleRepository.saveSale(sale: sale)
            }
            logger.info("UI test seed: wrote sample data, total \(clock.now - start)")
        } catch {
            logger.error("UI test seed failed: \(error.localizedDescription)")
        }
        let owner = AppUser(id: Self.userId, name: "UI Test owner", email: "uitest@apoorva.app", role: .admin,
                            status: "active", assignedOrgs: [], createdAt: Date(),
                            selectedOrganization: OrganizationSnapshot(orgId: Self.orgId, name: Self.shopName(for: vertical)))
        fakeUserService?.publish(owner)
        logger.info("UI test seed: published owner after \(clock.now - start)")
    }

    static func shopName(for vertical: Vertical) -> String {
        vertical == .kirana ? "Sri Lakshmi Stores" : "Glitz Gifts & Fancy"
    }

    static func settings(for vertical: Vertical) -> OrgSettings {
        var settings = OrgSettings()
        settings.profile = OrgSettings.Profile(shopName: shopName(for: vertical), phone: "98480 12345",
                                               address: "Ameerpet, Hyderabad", billPrefix: "D-", vertical: vertical,
                                               setupCompletedAt: Date())
        settings.flags.org = vertical.defaultFlags
        settings.plan = OrgSettings.Plan(tier: .pro)
        return settings
    }

    /// Fixture aggregates (visits, spend, dues) are fixed values, not derived from `sales(for:)`; the Customers list reads them as stored.
    static func customers(now: Date = Date()) -> [Customer] {
        let day: TimeInterval = 86_400
        func make(_ name: String, _ phone: String, createdDaysAgo: Double, lastVisit: Date?, visits: Int, spent: Double, due: Double) -> Customer {
            Customer(name: name, phone: phone, createdAt: now.addingTimeInterval(-day * createdDaysAgo).timeIntervalSince1970,
                     lastPurchaseDate: lastVisit?.timeIntervalSince1970, totalSales: visits, totalAmountSpent: spent,
                     updatedAt: now.timeIntervalSince1970, isDeleted: false, dueBalance: due)
        }
        return [
            make("Ravi Kumar", "9848012345", createdDaysAgo: 60, lastVisit: now, visits: 4, spent: 2_400, due: 0),
            make("Meena S", "9123456780", createdDaysAgo: 60, lastVisit: now, visits: 4, spent: 2_400, due: 1_120),
            make("Sneha P", "9988776655", createdDaysAgo: 60, lastVisit: now, visits: 4, spent: 2_400, due: 0),
            make("Anil Regular", "9000000005", createdDaysAgo: 90, lastVisit: now.addingTimeInterval(-day * 3), visits: 6, spent: 5_400, due: 0),
            make("Kavya New", "9000000006", createdDaysAgo: 0, lastVisit: nil, visits: 0, spent: 0, due: 0),
        ]
    }

    static func sales(for vertical: Vertical, now: Date = Date()) -> [Sale] {
        let customers = [("Ravi Kumar", "9848012345"), ("Meena S", "9123456780"), ("Sneha P", "9988776655")]
        return items(for: vertical).prefix(6).enumerated().map { index, item in
            let price = item.sellPrice ?? 100
            let qty = 1 + index % 3
            let total = price * Double(qty)
            let customer = customers[index % customers.count]
            return Sale(id: "demo-\(index)", staffId: userId, customerPhone: customer.1, customerName: customer.0,
                        items: [SaleItem(categoryId: item.id, categoryName: item.name, qty: qty,
                                         stickerPrice: price, finalPrice: price, discountType: .percentage)],
                        subtotal: total, overallDiscountPercent: 0, overallDiscountAmount: 0,
                        roundOff: 0, netPayable: total,
                        payments: [index % 2 == 0 ? .cash : .upi: total],
                        timestamp: now.addingTimeInterval(Double(-index) * 1_800), source: "POS",
                        status: "Completed", whatsappStatus: "unsent", billNumber: "D-\(1040 + index)")
        }
    }

    static func items(for vertical: Vertical) -> [InventoryItem] {
        let rows: [(String, Double, Int, Bool)]
        if vertical == .kirana {
            rows = [("Toor Dal 1kg", 160, 24, true), ("Sona Masoori Rice 5kg", 340, 12, true), ("Sunflower Oil 1L", 145, 3, true),
                    ("Sugar 1kg", 46, 40, false), ("Tea Powder 250g", 120, 18, true), ("Onions (kg)", 35, 50, true)]
        } else {
            rows = [("Glass Bangles", 120, 40, true), ("Teddy 12in", 499, 3, true), ("Gift Wrap Roll", 30, 5, true),
                    ("Photo Frame", 250, 14, false), ("Hair Clips Set", 80, 30, true), ("Key Chain", 60, 22, false)]
        }
        return rows.enumerated().map { index, row in
            var item = InventoryItem(id: "demo-item-\(index)", name: row.0, currentStock: row.2, billMachineNumber: index + 1,
                                     isHotkey: row.3, sellPrice: row.1, costPrice: row.1 * 0.7, unit: vertical == .kirana && index == 5 ? "kg" : "pc")
            // Tea Powder is the kirana variant item (sizes, no colours).
            if vertical == .kirana && index == 4 { item.variantsJSON = #"{"sizes":["100g","250g","500g"],"colours":[]}"# }
            return item
        }
    }
}
#endif
