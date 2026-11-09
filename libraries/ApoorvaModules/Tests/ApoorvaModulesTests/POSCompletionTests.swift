//
//  POSCompletionTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaRepository
@testable import ApoorvaModules

private func stockItem(_ id: String, price: Double? = 100, wholesale: Double? = nil, unit: String? = nil,
                       barcode: String? = nil, variants: String? = nil) -> InventoryItem {
    var item = InventoryItem(id: id, name: id.capitalized, currentStock: 10)
    item.sellPrice = price
    item.wholesalePrice = wholesale
    item.unit = unit
    item.barcode = barcode
    item.variantsJSON = variants
    return item
}

final class RecordingLifecycle: SaleLifecycleRepositoryProtocol, @unchecked Sendable {
    var recorded: [Sale] = []
    func recordEffects(of sale: Sale, by actorId: String) async throws { recorded.append(sale) }
    func cancel(saleId: String, reason: String, by actorId: String) async throws -> Sale { throw SaleLifecycleError.notFound }
    func undo(saleId: String, by actorId: String, now: Date) async throws -> Sale { throw SaleLifecycleError.notFound }
    func edit(_ edited: Sale, reason: String, by actorId: String) async throws {}
}

@MainActor
struct POSBillingTests {
    private func makeSUT(_ items: [InventoryItem]) async -> POSViewModel {
        let inventory = MockPOSInventoryRepository()
        inventory.items = items
        let vm = POSViewModel(inventoryRepository: inventory, heldBillRepository: MockPOSHeldBillRepository())
        await vm.prepareData()
        return vm
    }

    @Test func tapAddsPricedItemsAndRoutesTheRest() async {
        let vm = await makeSUT([stockItem("pen"), stockItem("legacy", price: nil), stockItem("dal", price: 140, unit: "kg"),
                                stockItem("bangle", variants: #"{"sizes":["2.4"],"colours":[]}"#)])
        let pen = vm.item(id: "pen")!
        #expect(vm.tap(pen) == .added)
        #expect(vm.tap(pen) == .added)
        #expect(vm.quantity(of: pen) == 2)
        #expect(vm.tap(vm.item(id: "legacy")!) == .needsPrice(itemId: "legacy"))
        #expect(vm.tap(vm.item(id: "dal")!) == .needsWeight(itemId: "dal"))
        #expect(vm.tap(vm.item(id: "bangle")!) == .needsVariant(itemId: "bangle"))
        #expect(vm.totalPayable == 200)
    }

    @Test func weighedAndVariantLinesPriceCorrectly() async {
        let vm = await makeSUT([stockItem("dal", price: 140, unit: "kg"), stockItem("bangle", price: 120)])
        vm.addWeighted(vm.item(id: "dal")!, weight: 0.5, pricePerUnit: 140)
        vm.addVariant(vm.item(id: "bangle")!, variant: "2.4 · Ruby", quantity: 2)
        vm.addVariant(vm.item(id: "bangle")!, variant: "2.4 · Ruby", quantity: 1)
        vm.addVariant(vm.item(id: "bangle")!, variant: "2.6 · Gold", quantity: 1)
        #expect(vm.cart.items.count == 3)
        #expect(vm.totalPayable == 70 + 360 + 120)
        #expect(vm.cart.items[0].displayName == "Dal · 0.5 kg")
        let line = SaleItem(cartItem: vm.cart.items[0])
        #expect(line.qty == 1)
        #expect(line.totalAmount == 70)
        #expect(line.weight == 0.5)
    }

    @Test func wholesaleTierRepricesTheBill() async {
        let vm = await makeSUT([stockItem("clip", price: 99, wholesale: 70)])
        _ = vm.tap(vm.item(id: "clip")!)
        vm.setPriceTier("wholesale")
        #expect(vm.totalPayable == 70)
        vm.setPriceTier("retail")
        #expect(vm.totalPayable == 99)
    }

    @Test func calculatorScanAndDiscount() async {
        let vm = await makeSUT([stockItem("soap", price: 38, barcode: "890123")])
        "120".forEach { vm.calculatorKey(String($0)) }
        vm.addCalculatorAmount()
        #expect(vm.calculatorText.isEmpty)
        #expect(vm.addScanned(barcode: "890123")?.id == "soap")
        #expect(vm.addScanned(barcode: "000") == nil)
        #expect(vm.totalPayable == 158)
        vm.applyDiscount(amount: 500, percent: nil)
        #expect(vm.cart.flatDiscount == 158)
        #expect(vm.totalPayable == 0)
    }

    @Test func searchMatchesBarcodeAndDesignCode() async {
        var haram = stockItem("haram")
        haram.designCode = "NK-118"
        let vm = await makeSUT([haram, stockItem("pen", barcode: "555")])
        vm.searchText = "nk-1"
        #expect(vm.visibleItems.map(\.id) == ["haram"])
        vm.searchText = "555"
        #expect(vm.visibleItems.map(\.id) == ["pen"])
    }
}

@MainActor
struct CheckoutModeTests {
    private func makeSUT(total: Double, customer: String? = nil) -> (CheckoutViewModel, StubSaleRepository, RecordingLifecycle) {
        let cart = PosCart(items: [CartItem(category: stockItem("pen"), mrp: total, quantity: 1)],
                           customerPhone: customer, customerName: customer == nil ? nil : "Asha")
        let sales = StubSaleRepository()
        let lifecycle = RecordingLifecycle()
        let users = MockUserRepository()
        users.currentUser = try? makeModuleUser()
        return (CheckoutViewModel(cart: cart, heldBillId: nil, saleRepository: sales, userRepository: users, lifecycle: lifecycle),
                sales, lifecycle)
    }

    @Test func roundsOffAndWorksOutChange() {
        let (vm, _, _) = makeSUT(total: 582.6)
        #expect(vm.finalTotal == 583)
        vm.cashReceivedText = "600"
        #expect(vm.changeDue == 17)
    }

    @Test func creditNeedsACustomer() async {
        let (vm, sales, _) = makeSUT(total: 100)
        vm.mode = .credit
        #expect(vm.creditNeedsCustomer)
        #expect(await vm.confirmSale() == nil)
        #expect(sales.sales.isEmpty)
    }

    @Test func splitSettlesThenConfirmsAndRecordsEffects() async {
        let (vm, sales, lifecycle) = makeSUT(total: 1236, customer: "9")
        vm.mode = .split
        vm.splitEntryMode = .cash
        "620".forEach { vm.splitKey(String($0)) }
        vm.confirmSplitEntry()
        #expect(vm.splitEntryMode == .upi)
        "500".forEach { vm.splitKey(String($0)) }
        vm.confirmSplitEntry()
        #expect(!vm.isSettled)
        vm.confirmSplitEntry() // remainder by card
        #expect(vm.isSettled)
        let sale = await vm.confirmSale()
        #expect(sale?.payments == [.cash: 620, .upi: 500, .card: 116])
        #expect(sales.sales.count == 1)
        #expect(lifecycle.recorded.count == 1)
    }
}

@MainActor
struct LineAndDiscountTests {
    @Test func lineEditAppliesAmountDiscountAndWarranty() {
        let vm = LineEditViewModel(line: CartItem(category: stockItem("teddy", price: 499), mrp: 499, quantity: 1), isNew: false)
        vm.discountMode = .amount
        vm.discountText = "50"
        vm.hasWarranty = true
        #expect(vm.lineTotal == 449)
        let line = vm.build()
        #expect(line.totalItemsPrice == 449)
        #expect(line.discountType == .amount)
        #expect(line.warrantyMonths == 6)
    }

    @Test func discountAboveLimitNeedsAManagerPin() throws {
        let pins = InMemoryPinStore()
        try pins.setPin("4321", for: "m1")
        let manager = Member(id: "m1", name: "Ravi", role: .manager)
        let vm = BillDiscountViewModel(subtotal: 1177, currentAmount: 0, currentPercent: nil, limitPercent: 10,
                                       managers: [manager], pinStore: pins)
        vm.preset(10)
        #expect(vm.amount == 118)
        #expect(vm.canApply)
        vm.preset(15)
        #expect(vm.needsApproval)
        "1111".forEach { _ = vm.managerKey(.digit(Int(String($0))!)) }
        #expect(vm.errorMessage != nil)
        #expect(vm.needsApproval)
        var approved = false
        "4321".forEach { approved = vm.managerKey(.digit(Int(String($0))!)) }
        #expect(approved)
        #expect(vm.canApply)
        vm.roundTotal()
        #expect(vm.newTotal == 1150)
    }

    @Test func weightEntryConvertsBothWays() {
        var entry = WeightEntry(pricePerUnit: 140)
        entry.preset(grams: 250)
        #expect(entry.amount == 35)
        entry.mode = .amount
        entry.text = "70"
        #expect(entry.weight == 0.5)
    }
}

@MainActor
struct ReturnAndPackageTests {
    private func original() -> Sale {
        Sale(id: "s1", staffId: "u1", customerPhone: "9", customerName: "Asha",
             items: [SaleItem(id: "l1", categoryId: "bangle", categoryName: "Glass Bangles", qty: 2, stickerPrice: 120, finalPrice: 120, discountType: .percentage),
                     SaleItem(id: "l2", categoryId: "frame", categoryName: "Photo Frame", qty: 1, stickerPrice: 349, finalPrice: 349, discountType: .percentage)],
             subtotal: 589, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 589,
             payments: [.cash: 589], timestamp: Date(), source: "POS", status: "Completed", whatsappStatus: "unsent", billNumber: "GG-298")
    }

    @Test func cashReturnSavesALinkedReturnBill() async {
        let sales = StubSaleRepository()
        sales.sales = [original()]
        let lifecycle = RecordingLifecycle()
        let vm = ReturnViewModel(saleId: "s1", saleRepository: sales, lifecycle: lifecycle)
        await vm.load()
        vm.toggle("l1")
        #expect(vm.refundAmount == 240)
        #expect(!vm.canProcess)
        vm.reason = "Size mismatch"
        let returned = await vm.process()
        #expect(returned?.returnOfSaleId == "s1")
        #expect(returned?.isReturn == true)
        #expect(returned?.payments == [.cash: 240])
        #expect(lifecycle.recorded.first?.id == returned?.id)
    }

    @Test func exchangeCartNetsOffReturnedItems() async {
        let sales = StubSaleRepository()
        sales.sales = [original()]
        let vm = ReturnViewModel(saleId: "s1", saleRepository: sales, lifecycle: RecordingLifecycle())
        await vm.load()
        vm.toggle("l1")
        vm.setQty(1, for: "l1")
        vm.refund = .exchange
        let cart = vm.exchangeCart()
        #expect(cart.items.first?.quantity == -1)
        #expect(cart.totalFinalPrice == -120)
        #expect(cart.customerPhone == "9")
    }

    @Test func usingASessionCountsDown() async {
        let package = ServicePackage(id: "p1", name: "Glow Facial × 5", price: 6500, sessions: 5)
        let owned = CustomerPackage(id: "c1", package: package, customerPhone: "9", customerName: "Anjali", sessionsUsed: 4)
        let vm = PackagesViewModel(customerPhone: "9", customerName: "Anjali",
                                   packages: StubOrgRepository<ServicePackage>([package]),
                                   customerPackages: StubOrgRepository<CustomerPackage>([owned]))
        await vm.load()
        #expect(await vm.useSession(vm.firstActive!))
        #expect(vm.owned.first?.sessionsLeft == 0)
        #expect(vm.firstActive == nil)
    }

    @Test func packageLinesBecomeCustomerPackagesAfterTheBill() async {
        let package = ServicePackage(id: "p1", name: "Monthly Glow", price: 2999, sessions: 4)
        let owned = StubOrgRepository<CustomerPackage>()
        let vm = PackagesViewModel(customerPhone: "9", customerName: "Anjali",
                                   packages: StubOrgRepository<ServicePackage>([package]), customerPackages: owned)
        let line = vm.cartLine(for: package)
        let sale = Sale(id: "s9", staffId: "u1", customerPhone: "9", customerName: "Anjali", items: [SaleItem(cartItem: line)],
                        subtotal: 2999, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 2999,
                        payments: [.upi: 2999], timestamp: Date(), source: "POS", status: "Completed", whatsappStatus: "unsent")
        await PackagesViewModel.recordPurchases(in: sale, packages: StubOrgRepository<ServicePackage>([package]), customerPackages: owned)
        #expect(owned.documents.values.first?.packageId == "p1")
        #expect(owned.documents.values.first?.saleId == "s9")
    }
}

@MainActor
struct ReceiptAndPickerTests {
    @Test func thermalReceiptFitsThePaper() {
        let sale = Sale(id: "s1", staffId: "u1", customerPhone: "", customerName: "Walk-in",
                        items: [SaleItem(categoryId: "atta", categoryName: "Aashirvaad Atta 5kg Premium Pack", qty: 1, stickerPrice: 265,
                                         finalPrice: 265, discountType: .percentage, warrantyMonths: 6)],
                        subtotal: 265, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0, netPayable: 265,
                        payments: [.cash: 265], timestamp: Date(), source: "POS", status: "Completed", whatsappStatus: "unsent", billNumber: "A-1047")
        let lines = ReceiptFormatter.thermalLines(for: sale, settings: OrgSettings(), shopName: "Sri Lakshmi Stores")
        #expect(lines.allSatisfy { $0.count <= 32 })
        #expect(lines.contains { $0.hasPrefix("TOTAL") && $0.hasSuffix("Rs 265.00") })
        #expect(lines.contains { $0.contains("Warranty till") })
        #expect(!lines.contains { $0.contains("GST") })
    }

    @Test func upiLinkCarriesTheAmount() {
        let link = UPILink.pay(upiId: "sri.lakshmi@okaxis", payee: "Sri Lakshmi", amount: 583, note: "Bill")
        #expect(link.hasPrefix("upi://pay?"))
        #expect(link.contains("pa=sri.lakshmi@okaxis"))
        #expect(link.contains("am=583.00"))
    }

    @Test func quickAddSavesAndReusesByPhone() async {
        let repository = StubCustomerRepository()
        let vm = CustomerPickerViewModel(repository: repository)
        vm.newPhone = "98480 55667"
        vm.newName = "Kiran"
        #expect(vm.canAdd)
        let first = await vm.addCustomer()
        #expect(first?.phone == "9848055667")
        #expect(repository.customers.count == 1)
        let again = await vm.addCustomer()
        #expect(again?.phone == first?.phone)
        #expect(repository.customers.count == 1)
    }
}
