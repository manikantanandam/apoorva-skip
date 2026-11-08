//
//  POSViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class POSViewModel {

    public var cart = PosCart()
    public var hotkeyItems: [InventoryItem] = []
    public var allCategories: [InventoryItem] = []
    public var activeHeldBillId: String?
    public var heldBillsCount: Int = 0
    public var isHolding: Bool = false
    public var errorMessage: String?

    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let heldBillRepository: HeldBillRepositoryProtocol

    public init(inventoryRepository: InventoryItemRepositoryProtocol,
                heldBillRepository: HeldBillRepositoryProtocol) {
        self.inventoryRepository = inventoryRepository
        self.heldBillRepository = heldBillRepository
    }

    public var customerName: String {
        get { cart.customerName ?? "" }
        set { cart.customerName = newValue.isEmpty ? nil : newValue }
    }

    public var customerPhoneNumber: String {
        get { cart.customerPhone ?? "" }
        set { cart.customerPhone = newValue.isEmpty ? nil : newValue }
    }

    public var cartItemCount: Int { cart.totalItemsCount }
    public var totalPayable: Double { cart.totalPayable }

    public func prepareData() async {
        do {
            let items = try await inventoryRepository.getInventoryItems()
            apply(items)
            try await inventoryRepository.sync(force: false)
            apply(try await inventoryRepository.getInventoryItems())
            await refreshHeldBillsCount()
        } catch {
            print("POS prepareData failed \(error.localizedDescription)")
        }
    }

    public func refreshHeldBillsCount() async {
        do {
            heldBillsCount = try await heldBillRepository.getHeldBills().count
        } catch {
            print("Failed to load held bills \(error.localizedDescription)")
        }
    }

    /// Looks up an existing cart line by category id — used to resolve `.lineEdit(itemId:)`
    /// into either an add (not found) or edit (found) for the price calculator.
    public func cartItem(forCategoryId id: String) -> (index: Int, item: CartItem)? {
        guard let index = cart.items.firstIndex(where: { $0.category.id == id }) else { return nil }
        return (index, cart.items[index])
    }

    public func addOrUpdate(_ item: CartItem) {
        if let index = cart.items.firstIndex(where: { $0.category.id == item.category.id }) {
            cart.items[index] = item
        } else {
            cart.items.append(item)
        }
    }

    public func remove(at index: Int) {
        guard cart.items.indices.contains(index) else { return }
        cart.items.remove(at: index)
    }

    public func holdCurrentBill() async {
        guard !cart.items.isEmpty else { return }
        isHolding = true
        defer { isHolding = false }

        let bill = HeldBill(
            id: activeHeldBillId ?? UUID().uuidString,
            customerName: cart.customerName ?? "",
            customerPhone: cart.customerPhone ?? "",
            items: cart.items,
            total: cart.totalPayable
        )
        do {
            if activeHeldBillId != nil {
                try await heldBillRepository.updateHeldBill(bill)
            } else {
                try await heldBillRepository.saveHeldBill(bill)
            }
            clearCart()
            await refreshHeldBillsCount()
        } catch {
            errorMessage = "Couldn't hold this bill. Please try again."
        }
    }

    public func resume(heldBill: HeldBill) {
        cart = PosCart(
            items: heldBill.items,
            customerPhone: heldBill.customerPhone.isEmpty ? nil : heldBill.customerPhone,
            customerName: heldBill.customerName.isEmpty ? nil : heldBill.customerName
        )
        activeHeldBillId = heldBill.id
    }

    /// Rebuilds the cart from a past sale — the "Edit Sale" action on the receipt screen.
    public func load(from sale: Sale) {
        let items = sale.items.map { saleItem in
            CartItem(
                category: InventoryItem(id: saleItem.categoryId, name: saleItem.categoryName),
                mrp: saleItem.stickerPrice,
                discountPercent: saleItem.discountPercent,
                quantity: saleItem.qty,
                discountType: saleItem.discountType
            )
        }
        cart = PosCart(
            items: items,
            customerPhone: sale.customerPhone.isEmpty ? nil : sale.customerPhone,
            customerName: sale.customerName.isEmpty ? nil : sale.customerName
        )
        activeHeldBillId = nil
    }

    public func selectCustomer(_ customer: Customer?) {
        cart.customerName = customer?.name
        cart.customerPhone = customer?.phone
    }

    public func clearCart() {
        cart = PosCart()
        activeHeldBillId = nil
    }

    private func apply(_ items: [InventoryItem]) {
        allCategories = items.sorted()
        hotkeyItems = items.hotItems
    }
}
