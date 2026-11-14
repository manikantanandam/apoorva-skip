//
//  ApoorvaModulesTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaServices
import ApoorvaModels
import ApoorvaUtilities
import ApoorvaRepository
@testable import ApoorvaModules

final class MockAuthService: AuthServicing, @unchecked Sendable {
    var loginCalls: [(String, String)] = []
    var logoutCount = 0
    var shouldThrow = false

    struct MockError: Error {}

    var currentUserStream: AsyncStream<AppUser?> {
        AsyncStream { $0.finish() }
    }

    func login(email: String, password: String) async throws {
        loginCalls.append((email, password))
        if shouldThrow { throw MockError() }
    }

    func logout() throws {
        logoutCount += 1
        if shouldThrow { throw MockError() }
    }
}

@MainActor
struct LoginViewModelTests {
    @Test func loginDisabledWhenFieldsEmpty() {
        let vm = LoginViewModel(authService: MockAuthService(), environment: .debug)
        vm.username = ""
        #expect(!vm.isLoginEnabled)
        vm.username = "a@b.com"
        vm.password = ""
        #expect(!vm.isLoginEnabled)
    }

    @Test func loginEnabledWhenFieldsFilled() {
        let vm = LoginViewModel(authService: MockAuthService(), environment: .debug)
        vm.username = "a@b.com"
        vm.password = "pw"
        #expect(vm.isLoginEnabled)
    }

    @Test func loginPressedCallsServiceWithCredentials() async throws {
        let auth = MockAuthService()
        let vm = LoginViewModel(authService: auth, environment: .debug)
        vm.username = "a@b.com"
        vm.password = "pw"
        vm.loginPressed()
        for _ in 0..<50 where auth.loginCalls.isEmpty { try await Task.sleep(nanoseconds: 100_000_000) }
        #expect(auth.loginCalls.count == 1)
        #expect(auth.loginCalls.first?.0 == "a@b.com")
    }

    @Test func loginPressedSkipsWhenDisabled() async throws {
        let auth = MockAuthService()
        let vm = LoginViewModel(authService: auth, environment: .debug)
        vm.username = ""
        vm.loginPressed()
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(auth.loginCalls.isEmpty)
    }

    @Test func loginPressedSetsErrorMessageOnFailure() async throws {
        let auth = MockAuthService()
        auth.shouldThrow = true
        let vm = LoginViewModel(authService: auth, environment: .debug)
        vm.username = "a@b.com"
        vm.password = "pw"
        vm.loginPressed()
        // Poll rather than a fixed sleep: under a busy parallel run 100 ms isn't always enough.
        for _ in 0..<40 where vm.errorMessage == nil {
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        #expect(auth.loginCalls.count == 1)
        #expect(vm.errorMessage != nil)
    }

    @Test func loginPressedClearsErrorMessageOnNewAttempt() async throws {
        let auth = MockAuthService()
        let vm = LoginViewModel(authService: auth, environment: .debug)
        vm.username = "a@b.com"
        vm.password = "pw"
        vm.errorMessage = "stale error"
        vm.loginPressed()
        #expect(vm.errorMessage == nil)
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(vm.errorMessage == nil)
    }
}

@MainActor
struct ProfileViewModelTests {
    @Test func logoutPressedCallsServiceAndClearsLocalData() async {
        let auth = MockAuthService()
        var clearedLocalData = false
        let vm = ProfileViewModel(
            userRepository: MockUserRepository(),
            authService: auth,
            clearLocalData: { clearedLocalData = true }
        )
        await vm.logoutPressed()
        #expect(auth.logoutCount == 1)
        #expect(clearedLocalData)
    }

    @Test func logoutPressedSkipsClearOnServiceError() async {
        let auth = MockAuthService()
        auth.shouldThrow = true
        var clearedLocalData = false
        let vm = ProfileViewModel(
            userRepository: MockUserRepository(),
            authService: auth,
            clearLocalData: { clearedLocalData = true }
        )
        await vm.logoutPressed()
        #expect(auth.logoutCount == 1)
        #expect(!clearedLocalData)
    }
}

final class MockPOSInventoryRepository: InventoryItemRepositoryProtocol, @unchecked Sendable {
    var items: [InventoryItem] = []
    func getInventoryItems() async throws -> [InventoryItem] { items }
    func saveInventoryItem(item: InventoryItem) async throws {}
    func updateInventoryItem(_ item: InventoryItem) async throws {}
    func deleteInventoryItem(id: String) async throws {}
    func markAsDeleted(id: String) async throws {}
    func sync(force: Bool) async throws {}
    func lastSyncedAt() async throws -> Date? { nil }
}

final class MockPOSHeldBillRepository: HeldBillRepositoryProtocol, @unchecked Sendable {
    var heldBills: [HeldBill] = []
    var calls: [String] = []

    func getHeldBills() async throws -> [HeldBill] { heldBills }
    func saveHeldBill(_ heldBill: HeldBill) async throws { calls.append("save"); heldBills.append(heldBill) }
    func updateHeldBill(_ heldBill: HeldBill) async throws { calls.append("update") }
    func deleteHeldBill(id: String) async throws { calls.append("delete") }
    func markAsDeleted(id: String) async throws { calls.append("markDeleted") }
    func sync(force: Bool) async throws {}
}

let posTestCategory = InventoryItem(id: "cat-1", name: "Bangles")

func makeCartItem(category: InventoryItem = posTestCategory, mrp: Double = 100, discountPercent: Double = 10, quantity: Int = 2) -> CartItem {
    CartItem(category: category, mrp: mrp, discountPercent: discountPercent, quantity: quantity)
}

@MainActor
struct POSViewModelTests {
    private func makeSUT() -> (POSViewModel, MockPOSHeldBillRepository) {
        let heldBillRepository = MockPOSHeldBillRepository()
        let vm = POSViewModel(
            inventoryRepository: MockPOSInventoryRepository(),
            heldBillRepository: heldBillRepository
        )
        return (vm, heldBillRepository)
    }

    @Test func startsWithEmptyCart() {
        let (vm, _) = makeSUT()
        #expect(vm.cart.items.isEmpty)
        #expect(vm.customerName.isEmpty)
    }

    @Test func addOrUpdateAddsNewLineThenReplacesSameCategory() {
        let (vm, _) = makeSUT()
        let item = makeCartItem(quantity: 1)
        vm.addOrUpdate(item)
        #expect(vm.cart.items.count == 1)

        let updated = makeCartItem(quantity: 3)
        vm.addOrUpdate(updated)
        #expect(vm.cart.items.count == 1)
        #expect(vm.cart.items[0].quantity == 3)
    }

    @Test func removeDropsTheLineAtIndex() {
        let (vm, _) = makeSUT()
        vm.addOrUpdate(makeCartItem())
        vm.remove(at: 0)
        #expect(vm.cart.items.isEmpty)
    }

    @Test func holdCurrentBillSavesAndClearsCart() async {
        let (vm, heldBillRepository) = makeSUT()
        vm.addOrUpdate(makeCartItem())
        await vm.holdCurrentBill()
        #expect(heldBillRepository.calls == ["save"])
        #expect(vm.cart.items.isEmpty)
    }

    @Test func holdCurrentBillDoesNothingWhenCartEmpty() async {
        let (vm, heldBillRepository) = makeSUT()
        await vm.holdCurrentBill()
        #expect(heldBillRepository.calls.isEmpty)
    }

    @Test func resumeRestoresCartFromHeldBill() {
        let (vm, _) = makeSUT()
        let bill = HeldBill(customerName: "Priya", customerPhone: "123", items: [makeCartItem()], total: 180)
        vm.resume(heldBill: bill)
        #expect(vm.cart.items.count == 1)
        #expect(vm.customerName == "Priya")
        #expect(vm.activeHeldBillId == bill.id)
    }

    @Test func loadFromSaleRebuildsCartItems() {
        let (vm, _) = makeSUT()
        let saleItem = SaleItem(categoryId: "c1", categoryName: "Earrings", qty: 2, stickerPrice: 50, finalPrice: 45, discountType: .percentage)
        let sale = Sale(id: "s1", staffId: "u1", customerPhone: "999", customerName: "Arjun", items: [saleItem],
                         subtotal: 90, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0,
                         netPayable: 90, payments: [.cash: 90], timestamp: Date(), source: "POS",
                         status: "Completed", whatsappStatus: "unsent")
        vm.load(from: sale)
        #expect(vm.cart.items.count == 1)
        #expect(vm.customerName == "Arjun")
        #expect(vm.activeHeldBillId == nil)
    }
}
