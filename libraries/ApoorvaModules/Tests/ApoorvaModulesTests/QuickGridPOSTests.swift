//
//  QuickGridPOSTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
@testable import ApoorvaModules

private func quickItem(_ id: String, price: Double? = 100, hotkey: Bool = false, unit: String? = nil,
                       variants: String? = nil) -> InventoryItem {
    var item = InventoryItem(id: id, name: id.capitalized, currentStock: 10)
    item.sellPrice = price
    item.isHotkey = hotkey
    item.unit = unit
    item.variantsJSON = variants
    return item
}

private func sale(_ id: String, lines: [(String, Int)], daysAgo: Int = 1, status: String = "Completed") -> Sale {
    Sale(id: id, staffId: "u1", customerPhone: "", customerName: "",
         items: lines.map { SaleItem(categoryId: $0.0, categoryName: $0.0, qty: $0.1, stickerPrice: 10, finalPrice: 10, discountType: .percentage) },
         subtotal: 0, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 0,
         payments: [.cash: 0], timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
         source: "POS", status: status, whatsappStatus: "unsent", billNumber: id)
}

@MainActor
struct QuickGridItemsTests {
    private func makeSUT(_ items: [InventoryItem], sales: [Sale]? = nil) async -> POSViewModel {
        let inventory = MockPOSInventoryRepository()
        inventory.items = items
        let vm = POSViewModel(inventoryRepository: inventory, heldBillRepository: MockPOSHeldBillRepository(),
                              salesLoader: sales.map { sales in { @Sendable in sales } })
        await vm.prepareData()
        return vm
    }

    @Test func hotkeysComeFirst() async {
        let vm = await makeSUT([quickItem("a"), quickItem("b", hotkey: true)], sales: [sale("s1", lines: [("a", 5)])])
        #expect(vm.quickItems.map(\.id) == ["b"])
    }

    @Test func bestSellersWhenNoHotkeys() async {
        let vm = await makeSUT([quickItem("a"), quickItem("b"), quickItem("c")],
                               sales: [sale("s1", lines: [("c", 3), ("b", 1)]), sale("s2", lines: [("b", 1)])])
        #expect(vm.quickItems.map(\.id) == ["c", "b"])
    }

    @Test func firstItemsWhenNoHotkeysOrSales() async {
        let items = (1...10).map { quickItem(String(format: "i%02d", $0)) }
        let vm = await makeSUT(items)
        #expect(vm.quickItems.count == POSViewModel.quickItemLimit)
        #expect(vm.quickItems.first?.id == "i01")
    }

    @Test func bestSellersSkipOldCancelledAndOneOffLines() {
        let since = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let ids = POSViewModel.bestSellerIds(from: [
            sale("s1", lines: [("pen", 1), ("custom-x", 9), ("package:gold", 9)]),
            sale("s2", lines: [("old", 9)], daysAgo: 45),
            sale("s3", lines: [("void", 9)], status: "Cancelled")
        ], since: since)
        #expect(ids == ["pen"])
    }

    @Test func quickActionRoutesVariantAndLooseItemsToTheirSheets() async {
        let vm = await makeSUT([quickItem("pen"), quickItem("dal", unit: "kg"),
                                quickItem("bangle", variants: #"{"sizes":["2.4"],"colours":[]}"#)])
        #expect(vm.quickAction(for: vm.item(id: "pen")!) == .quickAdd(itemId: "pen"))
        #expect(vm.quickAction(for: vm.item(id: "dal")!) == .weigh(itemId: "dal"))
        #expect(vm.quickAction(for: vm.item(id: "bangle")!) == .variant(itemId: "bangle"))
    }
}

@MainActor
struct QuickAddLineViewModelTests {
    private func newLine(mrp: Double = 200) -> QuickAddLineViewModel {
        QuickAddLineViewModel(line: CartItem(category: quickItem("chain"), mrp: mrp, quantity: 1, lineId: "l1"), isNew: true)
    }

    @Test func newLineOpensOnFinalPriceWithNoDiscount() {
        let vm = newLine()
        #expect(vm.mode == .finalPrice)
        #expect(vm.mrpText == "200")
        #expect(vm.discountPercent == 0)
        #expect(vm.net == 200)
    }

    @Test func finalPriceMode() {
        let vm = newLine()
        vm.valueText = "150"
        vm.increment()
        #expect(vm.discountPercent == 25)
        #expect(vm.gross == 400)
        #expect(vm.net == 300)
        #expect(vm.discount == 100)
        let line = vm.build()
        #expect(line.discountType == .finalPrice)
        #expect(line.finalPrice == 150)
        #expect(line.totalItemsPrice == 300)
    }

    @Test func percentAndAmountModes() {
        let vm = newLine()
        vm.setMode(.percent)
        vm.valueText = "10"
        #expect(vm.net == 180)
        #expect(vm.build().discountType == .percentage)
        vm.setMode(.amount)
        #expect(vm.valueText == "20")
        vm.valueText = "50"
        #expect(vm.net == 150)
        #expect(vm.build().discountType == .amount)
    }

    @Test func emptyMRPNeverProducesNaN() {
        let vm = newLine(mrp: 0)
        vm.valueText = "50"
        #expect(vm.discountPercent == 0)
        #expect(!vm.discountPercent.isNaN)
        #expect(!vm.isValid)
    }

    @Test func discountClampsToMRP() {
        let vm = newLine()
        vm.setMode(.amount)
        vm.valueText = "500"
        #expect(vm.discountPercent == 100)
        #expect(vm.net == 0)
    }

    @Test func editingRestoresTheSavedMode() {
        let vm = newLine()
        vm.valueText = "150"
        let edit = QuickAddLineViewModel(line: vm.build(), isNew: false)
        #expect(edit.mode == .finalPrice)
        #expect(edit.valueText == "150")
    }
}
