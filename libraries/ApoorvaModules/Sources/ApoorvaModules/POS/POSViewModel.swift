//
//  POSViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaRepository
import ManiLogger

private let logger = AppLogger(category: .ui)

/// What tapping an item on the POS should lead to.
public enum POSTapResult: Equatable, Sendable {
    case added
    /// No price on file (legacy items): enter it in the line editor.
    case needsPrice(itemId: String)
    case needsWeight(itemId: String)
    case needsVariant(itemId: String)
}

/// Variant options stored on an item as JSON in `variantsJSON`.
public struct ItemVariants: Codable, Sendable, Equatable {
    public struct Colour: Codable, Sendable, Equatable, Hashable {
        public let name: String
        public let hex: String
    }
    public var sizes: [String]
    public var colours: [Colour]

    public init(sizes: [String] = [], colours: [Colour] = []) {
        self.sizes = sizes
        self.colours = colours
    }

    public static func from(_ item: InventoryItem) -> ItemVariants? {
        guard let json = item.variantsJSON, let data = json.data(using: .utf8),
              let variants = try? JSONDecoder().decode(ItemVariants.self, from: data),
              !(variants.sizes.isEmpty && variants.colours.isEmpty) else { return nil }
        return variants
    }
}

/// The bill being built (designs 26–41). One instance per New Bill session.
@MainActor
@Observable
public class POSViewModel {

    public var cart = PosCart()
    public private(set) var items: [InventoryItem] = []
    public var hotkeyItems: [InventoryItem] = []
    public var allCategories: [InventoryItem] = []
    public var activeHeldBillId: String?
    public var heldBillsCount: Int = 0
    public var isHolding: Bool = false
    public var errorMessage: String?

    public var searchText = ""
    /// nil = "All", "frequent" = hotkeys, otherwise a category id.
    public var categoryFilter: String? = "frequent"
    public private(set) var categoryNames: [String: String] = [:]
    public private(set) var customer: Customer?
    public private(set) var staff: [Member] = []
    /// Parlour: the staff member new services are credited to (nil = skip).
    public var doneBy: Member?
    public var isCalculatorMode = false
    public var calculatorText = ""
    public var calculatorCategory = "Misc"

    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let heldBillRepository: HeldBillRepositoryProtocol
    private let memberRepository: (any OrgCollectionRepositoryProtocol<Member>)?
    private let customerRepository: CustomerRepositoryProtocol?
    private let categoryLoader: (@Sendable () async -> [String: String])?

    public init(inventoryRepository: InventoryItemRepositoryProtocol,
                heldBillRepository: HeldBillRepositoryProtocol,
                memberRepository: (any OrgCollectionRepositoryProtocol<Member>)? = nil,
                customerRepository: CustomerRepositoryProtocol? = nil,
                categoryLoader: (@Sendable () async -> [String: String])? = nil) {
        self.inventoryRepository = inventoryRepository
        self.heldBillRepository = heldBillRepository
        self.memberRepository = memberRepository
        self.customerRepository = customerRepository
        self.categoryLoader = categoryLoader
    }

    // MARK: - Customer fields (kept for the existing customer row)

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
    public var isWholesale: Bool { cart.priceTier == "wholesale" }

    // MARK: - Loading

    public func prepareData() async {
        do {
            apply(try await inventoryRepository.getInventoryItems())
            if let memberRepository {
                staff = ((try? await memberRepository.all()) ?? []).filter(\.isActive).sorted { $0.name < $1.name }
            }
            if let categoryLoader { categoryNames = await categoryLoader() }
            await refreshHeldBillsCount()
            try await inventoryRepository.sync(force: false)
            apply(try await inventoryRepository.getInventoryItems())
        } catch {
            logger.error("POS prepareData failed\(error.localizedDescription)")
        }
    }

    public func refreshHeldBillsCount() async {
        heldBillsCount = (try? await heldBillRepository.getHeldBills().count) ?? 0
    }

    private func apply(_ items: [InventoryItem]) {
        self.items = items.sorted()
        allCategories = self.items
        hotkeyItems = self.items.hotItems
        if hotkeyItems.isEmpty && categoryFilter == "frequent" { categoryFilter = nil }
    }

    // MARK: - Browsing

    /// Category chips: Frequent, All, then categories that have items.
    public var categoryOptions: [(id: String?, title: String)] {
        var options: [(id: String?, title: String)] = []
        if !hotkeyItems.isEmpty { options.append(("frequent", "Frequent")) }
        options.append((nil, "All"))
        let used = Set(items.compactMap(\.categoryId))
        for id in used.sorted() { options.append((id, categoryNames[id] ?? id)) }
        return options
    }

    public var visibleItems: [InventoryItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            return items.filter {
                $0.name.lowercased().contains(query)
                    || ($0.barcode ?? "").contains(query)
                    || ($0.designCode ?? "").lowercased().contains(query)
            }
        }
        switch categoryFilter {
        case "frequent": return hotkeyItems
        case .some(let id): return items.filter { $0.categoryId == id }
        case nil: return items
        }
    }

    public func item(id: String) -> InventoryItem? {
        items.first { $0.id == id } ?? cart.items.first { $0.category.id == id }?.category
    }

    /// Price for the current tier; nil when the item has no price on file.
    public func price(of item: InventoryItem) -> Double? {
        if isWholesale, let wholesale = item.wholesalePrice { return wholesale }
        return item.sellPrice
    }

    public func quantity(of item: InventoryItem) -> Int {
        cart.items.filter { $0.category.id == item.id }.reduce(0) { $0 + $1.quantity }
    }

    public func isLoose(_ item: InventoryItem) -> Bool {
        ["kg", "g", "l", "ml", "m"].contains(item.unit ?? "")
    }

    // MARK: - Adding

    public func tap(_ item: InventoryItem) -> POSTapResult {
        if ItemVariants.from(item) != nil { return .needsVariant(itemId: item.id) }
        if isLoose(item) { return .needsWeight(itemId: item.id) }
        guard price(of: item) != nil else { return .needsPrice(itemId: item.id) }
        addOne(item)
        return .added
    }

    public func addOne(_ item: InventoryItem) {
        if let index = cart.items.firstIndex(where: { $0.category.id == item.id && $0.variant == nil && $0.weight == nil }) {
            cart.items[index].quantity += 1
        } else {
            cart.items.append(CartItem(category: item, mrp: price(of: item) ?? 0, quantity: 1,
                                       doneByStaffId: doneBy?.id, doneByName: doneBy?.name,
                                       warrantyMonths: item.warrantyMonths))
        }
    }

    public func decrement(_ item: InventoryItem) {
        guard let index = cart.items.lastIndex(where: { $0.category.id == item.id }) else { return }
        if cart.items[index].quantity > 1 {
            cart.items[index].quantity -= 1
        } else {
            cart.items.remove(at: index)
        }
    }

    public func addWeighted(_ item: InventoryItem, weight: Double, pricePerUnit: Double) {
        guard weight > 0 else { return }
        cart.items.append(CartItem(category: item, mrp: pricePerUnit, quantity: 1, weight: weight,
                                   unit: item.unit ?? "kg", lineId: UUID().uuidString))
    }

    public func addVariant(_ item: InventoryItem, variant: String, quantity: Int) {
        let lineId = "\(item.id)#\(variant)"
        if let index = cart.items.firstIndex(where: { $0.lineId == lineId }) {
            cart.items[index].quantity += quantity
        } else {
            cart.items.append(CartItem(category: item, mrp: price(of: item) ?? 0, quantity: quantity, variant: variant))
        }
    }

    /// A one-off line for something not in the list (design 28). Optionally saved as a new item.
    public func addCustom(name: String, amount: Double, category: String, saveAsItem: Bool) async {
        guard amount > 0 else { return }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let item = InventoryItem(id: saveAsItem ? DocumentID.make() : "custom-\(UUID().uuidString)",
                                 name: trimmed.isEmpty ? category : trimmed, sellPrice: amount)
        if saveAsItem {
            try? await inventoryRepository.saveInventoryItem(item: item)
            items.append(item)
            items.sort()
        }
        cart.items.append(CartItem(category: item, mrp: amount, quantity: 1, lineId: UUID().uuidString))
    }

    // MARK: - Lines

    public func cartItem(forCategoryId id: String) -> (index: Int, item: CartItem)? {
        guard let index = cart.items.firstIndex(where: { $0.category.id == id }) else { return nil }
        return (index, cart.items[index])
    }

    public func line(id: String) -> CartItem? {
        cart.items.first { $0.lineId == id }
    }

    public func addOrUpdate(_ item: CartItem) {
        if let index = cart.items.firstIndex(where: { $0.lineId == item.lineId }) {
            cart.items[index] = item
        } else {
            cart.items.append(item)
        }
    }

    public func remove(at index: Int) {
        guard cart.items.indices.contains(index) else { return }
        cart.items.remove(at: index)
    }

    public func removeLine(id: String) {
        cart.items.removeAll { $0.lineId == id }
    }

    /// Parlour: credit a service line to a staff member (or clear it).
    public func assign(_ member: Member?, toLine id: String) {
        guard let index = cart.items.firstIndex(where: { $0.lineId == id }) else { return }
        cart.items[index].doneByStaffId = member?.id
        cart.items[index].doneByName = member?.name
    }

    // MARK: - Bill discount (design 34)

    public func applyDiscount(amount: Double, percent: Double?) {
        cart.flatDiscount = min(max(0, amount), cart.totalFinalPrice)
        cart.discountPercent = percent
    }

    // MARK: - Price tier (design 41)

    public func setPriceTier(_ tier: String) {
        cart.priceTier = tier
        for index in cart.items.indices where cart.items[index].weight == nil {
            let item = cart.items[index].category
            if let price = (tier == "wholesale" ? item.wholesalePrice : nil) ?? item.sellPrice {
                cart.items[index].mrp = price
            }
        }
    }

    // MARK: - Calculator mode (design 29)

    public func calculatorKey(_ key: String) {
        switch key {
        case "⌫": calculatorText = String(calculatorText.dropLast())
        case ".": if !calculatorText.contains(".") { calculatorText += calculatorText.isEmpty ? "0." : "." }
        default: if calculatorText.count < 8 { calculatorText += key }
        }
    }

    public func addCalculatorAmount() {
        guard let amount = Double(calculatorText), amount > 0 else { return }
        let number = cart.items.count + 1
        let item = InventoryItem(id: "custom-\(UUID().uuidString)", name: "Item \(number) · \(calculatorCategory)", sellPrice: amount)
        cart.items.append(CartItem(category: item, mrp: amount, quantity: 1, lineId: UUID().uuidString))
        calculatorText = ""
    }

    // MARK: - Scanning (design 53)

    /// Adds the item with this barcode; returns it, or nil when no item matches.
    @discardableResult
    public func addScanned(barcode: String) -> InventoryItem? {
        guard let item = items.first(where: { $0.barcode == barcode }) else { return nil }
        addOne(item)
        return item
    }

    // MARK: - Customer

    public func selectCustomer(_ customer: Customer?) {
        self.customer = customer
        cart.customerName = customer?.name
        cart.customerPhone = customer?.phone
        if let tier = customer?.priceTier { setPriceTier(tier) }
    }

    public func reloadCustomer() async {
        guard let phone = cart.customerPhone, let customerRepository else { return }
        customer = try? await customerRepository.getCustomer(phone: phone)
    }

    // MARK: - Hold / resume / edit

    public func holdCurrentBill() async {
        guard !cart.items.isEmpty else { return }
        isHolding = true
        defer { isHolding = false }

        let bill = HeldBill(
            id: activeHeldBillId ?? DocumentID.make(),
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

    /// Rebuilds the cart from a past sale — the "Edit Sale" / undo path.
    public func load(from sale: Sale) {
        let items = sale.items.map { saleItem in
            CartItem(
                category: InventoryItem(id: saleItem.categoryId, name: saleItem.categoryName),
                mrp: saleItem.stickerPrice,
                discountPercent: saleItem.discountPercent,
                quantity: saleItem.qty,
                discountType: saleItem.discountType,
                doneByStaffId: saleItem.doneByStaffId,
                doneByName: saleItem.doneByName,
                warrantyMonths: saleItem.warrantyMonths,
                lineId: UUID().uuidString
            )
        }
        cart = PosCart(
            items: items,
            customerPhone: sale.customerPhone.isEmpty ? nil : sale.customerPhone,
            customerName: sale.customerName.isEmpty || sale.customerName == "Walk-in" ? nil : sale.customerName
        )
        activeHeldBillId = nil
    }

    public func clearCart() {
        cart = PosCart()
        customer = nil
        activeHeldBillId = nil
    }
}
