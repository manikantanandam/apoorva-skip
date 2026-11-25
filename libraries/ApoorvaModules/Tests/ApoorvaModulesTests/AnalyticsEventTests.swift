//
//  AnalyticsEventTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaRepository
@testable import ApoorvaModules

private final class RecordingAnalytics: AnalyticsServicing, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []
    var names: [String] { events.map(\.name) }

    func log(_ event: AnalyticsEvent) { events.append(event) }
    func setUserProperty(_ value: String?, forName name: String) {}
    func setUserId(_ id: String?) {}
    func setAnalyticsCollectionEnabled(_ enabled: Bool) {}

    func first(_ name: String) -> [String: AnalyticsParameterValue]? { events.first { $0.name == name }?.parameters }
}

private func pricedItem(_ id: String, price: Double = 100, barcode: String? = nil) -> InventoryItem {
    var item = InventoryItem(id: id, name: id.capitalized, currentStock: 10)
    item.sellPrice = price
    item.barcode = barcode
    return item
}

@MainActor
struct POSAnalyticsTests {
    private func makeSUT(_ items: [InventoryItem]) async -> (POSViewModel, RecordingAnalytics) {
        let inventory = MockPOSInventoryRepository()
        inventory.items = items
        let analytics = RecordingAnalytics()
        let vm = POSViewModel(inventoryRepository: inventory, heldBillRepository: MockPOSHeldBillRepository(), analyticsService: analytics)
        await vm.prepareData()
        return (vm, analytics)
    }

    @Test func cartChangesLogAddAndRemoveWithSource() async {
        let (vm, analytics) = await makeSUT([pricedItem("pen", price: 40, barcode: "111")])
        _ = vm.tap(vm.item(id: "pen")!)
        vm.addScanned(barcode: "111")
        vm.addScanned(barcode: "999")
        vm.remove(at: 0)

        #expect(analytics.names == ["add_to_cart", "scan_used", "add_to_cart", "scan_used", "remove_from_cart"])
        #expect(analytics.events[0].parameters["source"] == .string("tap"))
        #expect(analytics.events[0].parameters["value"] == .double(40))
        #expect(analytics.events[0].parameters["currency"] == .string("INR"))
        #expect(analytics.events[2].parameters["source"] == .string("scan"))
        #expect(analytics.events[3].parameters["matched"] == .bool(false))
        #expect(analytics.events[4].parameters["value"] == .double(80))
        #expect(analytics.events[4].parameters["quantity"] == .int(2))
    }
}

@MainActor
struct CheckoutAnalyticsTests {
    private func makeSUT(total: Double, returnOf: String? = nil) -> (CheckoutViewModel, RecordingAnalytics) {
        var cart = PosCart(items: [CartItem(category: pricedItem("pen"), mrp: total, quantity: 1)])
        cart.returnOfSaleId = returnOf
        let users = MockUserRepository()
        users.currentUser = try? makeModuleUser()
        let analytics = RecordingAnalytics()
        let vm = CheckoutViewModel(cart: cart, heldBillId: nil, saleRepository: StubSaleRepository(), userRepository: users,
                                   analyticsService: analytics)
        return (vm, analytics)
    }

    @Test func beginCheckoutIsLoggedOnce() {
        let (vm, analytics) = makeSUT(total: 250)
        vm.checkoutStarted()
        vm.checkoutStarted()
        #expect(analytics.names == ["begin_checkout"])
        #expect(analytics.first("begin_checkout")?["value"] == .double(250))
    }

    @Test func confirmedSaleLogsPurchaseWithItsId() async {
        let (vm, analytics) = makeSUT(total: 300)
        vm.amountTexts[.cash] = "300"
        let sale = await vm.confirmSale()
        #expect(sale != nil)
        #expect(analytics.names == ["bill_saved", "purchase"])
        #expect(analytics.first("purchase")?["transaction_id"] == .string(sale?.id ?? ""))
        #expect(analytics.first("purchase")?["value"] == .double(300))
        #expect(analytics.first("purchase")?["payment_type"] == .string("Cash"))
    }

    @Test func returnBillLogsRefundAgainstTheOriginal() async {
        let (vm, analytics) = makeSUT(total: 120, returnOf: "sale-1")
        vm.amountTexts[.cash] = "120"
        _ = await vm.confirmSale()
        #expect(analytics.names == ["bill_saved", "refund"])
        #expect(analytics.first("refund")?["transaction_id"] == .string("sale-1"))
        #expect(analytics.first("refund")?["reason"] == .string("return"))
    }
}
