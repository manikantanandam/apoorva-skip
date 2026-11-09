//
//  InventoryViewModel.swift
//  ApoorvaModules
//
//  Inventory list (73), item detail (74), adjust (75), add/edit (76), categories (77), import (78).
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

public enum InventoryFilter: Hashable, Sendable {
    case all, low, out
    case category(String)
}

// MARK: - List (73)

@MainActor
@Observable
public class InventoryViewModel {
    public private(set) var items: [InventoryItem] = []
    public private(set) var categories: [ItemCategory] = []
    public var searchText = ""
    public var filter: InventoryFilter = .all

    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let categoryRepository: (any OrgCollectionRepositoryProtocol<ItemCategory>)?

    public init(inventoryRepository: InventoryItemRepositoryProtocol,
                categoryRepository: (any OrgCollectionRepositoryProtocol<ItemCategory>)? = nil) {
        self.inventoryRepository = inventoryRepository
        self.categoryRepository = categoryRepository
    }

    public func load() async {
        apply(try? await inventoryRepository.getInventoryItems())
        categories = ((try? await categoryRepository?.all()) ?? []).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
    }

    public func forceSync() async {
        try? await inventoryRepository.sync(force: true)
        await load()
    }

    private func apply(_ list: [InventoryItem]?) {
        items = (list ?? []).filter { !$0.isDeleted }.sorted()
    }

    public var lowCount: Int { items.filter { $0.isLowStock && $0.currentStock > 0 }.count }
    public var outCount: Int { items.filter { $0.currentStock <= 0 }.count }

    public var subtitle: String {
        var text = "\(items.count) items"
        if lowCount + outCount > 0 { text += " · \(lowCount + outCount) low" }
        return text
    }

    public func categoryName(_ id: String?) -> String? {
        guard let id else { return nil }
        return categories.first { $0.id == id }?.name ?? id
    }

    public var visible: [InventoryItem] {
        var list: [InventoryItem]
        switch filter {
        case .all: list = items
        case .low: list = items.filter { $0.isLowStock && $0.currentStock > 0 }
        case .out: list = items.filter { $0.currentStock <= 0 }
        case .category(let id): list = items.filter { $0.categoryId == id }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return list }
        return list.filter {
            $0.name.lowercased().contains(query) || ($0.barcode ?? "").contains(query) || ($0.designCode ?? "").lowercased().contains(query)
        }
    }

    public func status(of item: InventoryItem) -> (text: String, isOut: Bool)? {
        if item.currentStock <= 0 { return ("Out", true) }
        if item.isLowStock { return ("Low", false) }
        return nil
    }
}

// MARK: - Item detail (74)

@MainActor
@Observable
public final class InventoryItemViewModel {
    public let itemId: String
    public private(set) var item: InventoryItem?
    public private(set) var movements: [StockMovement] = []
    public private(set) var soldByDay: [(label: String, quantity: Double)] = []
    public private(set) var categoryName: String?

    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let saleRepository: SaleRepositoryProtocol
    private let movementRepository: any OrgCollectionRepositoryProtocol<StockMovement>
    private let categoryRepository: (any OrgCollectionRepositoryProtocol<ItemCategory>)?

    public init(itemId: String, inventoryRepository: InventoryItemRepositoryProtocol, saleRepository: SaleRepositoryProtocol,
                movementRepository: any OrgCollectionRepositoryProtocol<StockMovement>,
                categoryRepository: (any OrgCollectionRepositoryProtocol<ItemCategory>)? = nil) {
        self.itemId = itemId
        self.inventoryRepository = inventoryRepository
        self.saleRepository = saleRepository
        self.movementRepository = movementRepository
        self.categoryRepository = categoryRepository
    }

    public func load() async {
        item = try? await inventoryRepository.getInventoryItems().first { $0.id == itemId }
        movements = ((try? await movementRepository.all()) ?? []).filter { $0.itemId == itemId }.sorted { $0.createdAt > $1.createdAt }
        if let categoryId = item?.categoryId {
            categoryName = (try? await categoryRepository?.get(id: categoryId))??.name
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sales = ((try? await saleRepository.getSales()) ?? []).filter { !$0.isCancelled && !$0.isReturn }
        soldByDay = (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let quantity = sales.filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
                .flatMap(\.items).filter { $0.categoryId == itemId }.reduce(0.0) { $0 + ($1.weight ?? Double($1.qty)) }
            return (day.formatted(.dateTime.weekday(.narrow)), quantity)
        }
    }

    public var variantSummary: String? {
        guard let item, let variants = ItemVariants.from(item) else { return nil }
        let count = max(variants.sizes.count, 1) * max(variants.colours.count, 1)
        return "\(count) variants"
    }
}

// MARK: - Adjust (75)

@MainActor
@Observable
public final class StockAdjustViewModel {
    public enum Mode: String, CaseIterable, Sendable { case add = "Add", remove = "Remove", exact = "Set exact" }
    public enum Reason: String, CaseIterable, Sendable {
        case purchase = "Purchase", customerReturn = "Return", damage = "Damage", countFix = "Count fix"

        var movementReason: StockMovementReason {
            switch self {
            case .purchase: .purchase
            case .customerReturn: .customerReturn
            case .damage: .damage
            case .countFix: .adjustment
            }
        }
    }

    public let itemId: String
    public private(set) var item: InventoryItem?
    public var mode: Mode = .add
    public var quantityText = ""
    public var reason: Reason = .purchase
    public var isSaving = false
    public var errorMessage: String?

    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let stock: StockRepositoryProtocol
    private let actorId: String

    public init(itemId: String, inventoryRepository: InventoryItemRepositoryProtocol, stock: StockRepositoryProtocol, actorId: String) {
        self.itemId = itemId
        self.inventoryRepository = inventoryRepository
        self.stock = stock
        self.actorId = actorId
    }

    public func load() async {
        item = try? await inventoryRepository.getInventoryItems().first { $0.id == itemId }
    }

    public var quantity: Int { Int(quantityText) ?? 0 }
    public var current: Int { item?.currentStock ?? 0 }

    public var adjustment: StockAdjustment {
        switch mode {
        case .add: .add(quantity)
        case .remove: .remove(quantity)
        case .exact: .setExact(quantity)
        }
    }

    public var newStock: Int {
        switch mode {
        case .add: current + quantity
        case .remove: current - quantity
        case .exact: quantity
        }
    }

    public var heroText: String {
        switch mode {
        case .add: "+\(quantity)"
        case .remove: "−\(quantity)"
        case .exact: "\(quantity)"
        }
    }

    public var canSave: Bool { item != nil && (mode == .exact ? quantityText.isEmpty == false : quantity > 0) && newStock != current }

    public func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            item = try await stock.adjust(itemId: itemId, adjustment, reason: reason.movementReason, note: nil, by: actorId)
            return true
        } catch {
            errorMessage = "Couldn't save. Try again."
            return false
        }
    }
}

// MARK: - Add / edit (76)

@MainActor
@Observable
public final class ItemFormViewModel {
    public enum SoldAs: String, CaseIterable, Sendable {
        case piece = "Piece", pack = "Pack", kg = "Kg", metre = "Metre"

        var unit: String? {
            switch self {
            case .piece: nil
            case .pack: "pack"
            case .kg: "kg"
            case .metre: "m"
            }
        }

        static func from(_ unit: String?) -> SoldAs {
            switch unit {
            case "pack": .pack
            case "kg", "g": .kg
            case "m": .metre
            default: .piece
            }
        }
    }

    public enum WarrantyUnit: String, CaseIterable, Sendable { case days = "Days", months = "Months", years = "Years" }

    public let itemId: String?
    public var name = ""
    public var priceText = ""
    public var wholesaleText = ""
    public var soldAs: SoldAs = .piece
    public var stockText = ""
    public var hasWarranty = false
    public var warrantyValueText = "6"
    public var warrantyUnit: WarrantyUnit = .months
    public var hasVariants = false
    public var sizesText = ""
    public var coloursText = ""
    public var showsMore = false
    public var barcode = ""
    public var costText = ""
    public var categoryId: String?
    public var designCode = ""
    public var lowStockText = ""
    public private(set) var categories: [ItemCategory] = []
    public var isSaving = false
    public var errorMessage: String?

    private var original: InventoryItem?
    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let categoryRepository: (any OrgCollectionRepositoryProtocol<ItemCategory>)?
    private let audit: AuditLogging?

    public init(itemId: String?, inventoryRepository: InventoryItemRepositoryProtocol,
                categoryRepository: (any OrgCollectionRepositoryProtocol<ItemCategory>)?, audit: AuditLogging?) {
        self.itemId = itemId
        self.inventoryRepository = inventoryRepository
        self.categoryRepository = categoryRepository
        self.audit = audit
    }

    public var isEditing: Bool { itemId != nil }

    public func load() async {
        categories = ((try? await categoryRepository?.all()) ?? []).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
        guard let itemId, let item = try? await inventoryRepository.getInventoryItems().first(where: { $0.id == itemId }) else { return }
        original = item
        name = item.name
        priceText = item.sellPrice.map(Self.text) ?? ""
        wholesaleText = item.wholesalePrice.map(Self.text) ?? ""
        soldAs = .from(item.unit)
        stockText = String(item.currentStock)
        if let months = item.warrantyMonths, months > 0 {
            hasWarranty = true
            if months % 12 == 0 { warrantyUnit = .years; warrantyValueText = String(months / 12) } else { warrantyValueText = String(months) }
        }
        if let variants = ItemVariants.from(item) {
            hasVariants = true
            sizesText = variants.sizes.joined(separator: ", ")
            coloursText = variants.colours.map(\.name).joined(separator: ", ")
        }
        barcode = item.barcode ?? ""
        costText = item.costPrice.map(Self.text) ?? ""
        categoryId = item.categoryId
        designCode = item.designCode ?? ""
        lowStockText = item.lowStockThreshold.map(String.init) ?? ""
    }

    static func text(_ value: Double) -> String { value == value.rounded() ? String(Int(value)) : String(value) }

    /// Warranty in months; days round up to a month (receipts show months).
    public var warrantyMonths: Int? {
        guard hasWarranty, let value = Int(warrantyValueText), value > 0 else { return nil }
        switch warrantyUnit {
        case .days: return max(1, Int((Double(value) / 30).rounded(.up)))
        case .months: return value
        case .years: return value * 12
        }
    }

    static let palette = ["#B91C1C", "#047857", "#1D4ED8", "#CA8A04", "#E5E7EB", "#7C3AED", "#DB2777", "#111827"]

    var variantsJSON: String? {
        guard hasVariants else { return nil }
        let sizes = sizesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let colours = coloursText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            .enumerated().map { ItemVariants.Colour(name: $0.element, hex: Self.palette[$0.offset % Self.palette.count]) }
        guard !(sizes.isEmpty && colours.isEmpty),
              let data = try? JSONEncoder().encode(ItemVariants(sizes: sizes, colours: colours)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(priceText) ?? 0) > 0 }

    public func save() async -> InventoryItem? {
        guard canSave else {
            errorMessage = "Name and price are required."
            return nil
        }
        isSaving = true
        defer { isSaving = false }
        var item = original ?? InventoryItem(name: "")
        item.name = name.trimmingCharacters(in: .whitespaces)
        item.sellPrice = Double(priceText)
        item.wholesalePrice = Double(wholesaleText)
        item.unit = soldAs.unit
        item.currentStock = Int(stockText) ?? item.currentStock
        item.warrantyMonths = warrantyMonths
        item.variantsJSON = variantsJSON
        item.barcode = barcode.isEmpty ? nil : barcode
        item.costPrice = Double(costText)
        item.categoryId = categoryId
        item.designCode = designCode.isEmpty ? nil : designCode
        item.lowStockThreshold = Int(lowStockText)
        item.updatedAt = Date()
        do {
            if original == nil {
                try await inventoryRepository.saveInventoryItem(item: item)
            } else {
                try await inventoryRepository.updateInventoryItem(item)
            }
            await audit?.log(.stock, action: original == nil ? "item.add" : "item.edit", summary: item.name, targetId: item.id)
            return item
        } catch {
            errorMessage = "Couldn't save the item. Try again."
            return nil
        }
    }

    public func delete() async -> Bool {
        guard let original else { return false }
        do {
            try await inventoryRepository.markAsDeleted(id: original.id)
            await audit?.log(.stock, action: "item.delete", summary: original.name, targetId: original.id)
            return true
        } catch {
            errorMessage = "Couldn't delete the item."
            return false
        }
    }
}

// MARK: - Categories (77)

@MainActor
@Observable
public final class CategoriesViewModel {
    public private(set) var categories: [ItemCategory] = []
    public private(set) var counts: [String: Int] = [:]
    public var newName = ""

    private let repository: any OrgCollectionRepositoryProtocol<ItemCategory>
    private let inventoryRepository: InventoryItemRepositoryProtocol

    public init(repository: any OrgCollectionRepositoryProtocol<ItemCategory>, inventoryRepository: InventoryItemRepositoryProtocol) {
        self.repository = repository
        self.inventoryRepository = inventoryRepository
    }

    public func load() async {
        categories = ((try? await repository.all()) ?? []).filter { !$0.isDeleted }.sorted { $0.sortOrder < $1.sortOrder }
        let items = (try? await inventoryRepository.getInventoryItems()) ?? []
        counts = Dictionary(grouping: items.filter { !$0.isDeleted }, by: { $0.categoryId ?? "" }).mapValues(\.count)
    }

    public func add() async {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !categories.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        let category = ItemCategory(name: name, sortOrder: (categories.map(\.sortOrder).max() ?? -1) + 1)
        try? await repository.save(category)
        newName = ""
        await load()
    }

    public func rename(_ category: ItemCategory, to name: String) async {
        var updated = category
        updated.name = name.trimmingCharacters(in: .whitespaces)
        guard !updated.name.isEmpty else { return }
        try? await repository.save(updated)
        await load()
    }

    /// Removes the category; its items become uncategorised.
    public func delete(_ category: ItemCategory) async {
        var removed = category
        removed.isDeleted = true
        removed.updatedAt = Date()
        try? await repository.save(removed)
        await load()
    }

    /// Persists a drag-reorder: sortOrder follows the new positions.
    public func move(from source: IndexSet, to destination: Int) async {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        categories = reordered
        var changed: [ItemCategory] = []
        for (index, category) in reordered.enumerated() where category.sortOrder != index {
            var updated = category
            updated.sortOrder = index
            changed.append(updated)
        }
        try? await repository.saveAll(changed)
        await load()
    }
}

// MARK: - Import (78)

/// Parses a CSV of items. Columns are matched by header name; unknown columns are ignored.
public struct ItemCSV: Sendable {
    public struct Row: Sendable, Equatable {
        public let line: Int
        public let name: String
        public let category: String?
        public let price: Double?
        public let stock: Int?
        public let barcode: String?
        public let cost: Double?
        public var isReady: Bool { !name.isEmpty && (price ?? 0) > 0 }
    }

    public static let template = "Name,Category,Price,Stock,Barcode,Cost\nGlass Bangles,Bangles,120,24,8901234567012,80\n"

    public let columns: [String: Int]
    public let rows: [Row]

    public init(text: String) {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        let header = lines.first.map(Self.fields) ?? []
        var columns: [String: Int] = [:]
        let aliases: [String: [String]] = [
            "name": ["name", "item", "item name", "product"], "category": ["category", "group"],
            "price": ["price", "mrp", "sell price", "selling price", "rate"], "stock": ["stock", "qty", "quantity"],
            "barcode": ["barcode", "sku", "code"], "cost": ["cost", "cost price", "purchase price"]
        ]
        for (index, title) in header.enumerated() {
            let key = title.lowercased().trimmingCharacters(in: .whitespaces)
            if let match = aliases.first(where: { $0.value.contains(key) })?.key, columns[match] == nil { columns[match] = index }
        }
        self.columns = columns
        rows = lines.dropFirst().enumerated().map { offset, line in
            let fields = Self.fields(line)
            func value(_ key: String) -> String? {
                guard let index = columns[key], fields.indices.contains(index) else { return nil }
                let text = fields[index].trimmingCharacters(in: .whitespaces)
                return text.isEmpty ? nil : text
            }
            func number(_ key: String) -> Double? {
                value(key).flatMap { Double($0.replacingOccurrences(of: "₹", with: "").replacingOccurrences(of: ",", with: "")) }
            }
            return Row(line: offset + 2, name: value("name") ?? "", category: value("category"), price: number("price"),
                       stock: number("stock").map { Int($0) }, barcode: value("barcode"), cost: number("cost"))
        }
    }

    /// Splits one CSV line, honouring double-quoted fields.
    static func fields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for character in line {
            if character == "\"" { inQuotes.toggle() } else if character == ",", !inQuotes { fields.append(current); current = "" } else { current.append(character) }
        }
        fields.append(current)
        return fields
    }
}

@MainActor
@Observable
public final class ItemImportViewModel {
    public private(set) var fileName: String?
    public private(set) var csv: ItemCSV?
    public private(set) var isImporting = false
    public var errorMessage: String?

    private let inventoryRepository: InventoryItemRepositoryProtocol
    private let categoryRepository: any OrgCollectionRepositoryProtocol<ItemCategory>
    private let audit: AuditLogging?

    public init(inventoryRepository: InventoryItemRepositoryProtocol, categoryRepository: any OrgCollectionRepositoryProtocol<ItemCategory>,
                audit: AuditLogging?) {
        self.inventoryRepository = inventoryRepository
        self.categoryRepository = categoryRepository
        self.audit = audit
    }

    public func read(text: String, fileName: String) {
        self.fileName = fileName
        csv = ItemCSV(text: text)
        if csv?.columns["name"] == nil || csv?.columns["price"] == nil {
            errorMessage = "Couldn't find Name and Price columns. Use the template."
        } else {
            errorMessage = nil
        }
    }

    public var ready: [ItemCSV.Row] { csv?.rows.filter(\.isReady) ?? [] }
    public var needsAttention: [ItemCSV.Row] { csv?.rows.filter { !$0.isReady } ?? [] }

    /// Adds ready rows. Rows whose barcode or name already exists update that item instead. Returns the count.
    public func importReady() async -> Int {
        isImporting = true
        defer { isImporting = false }
        let existing = (try? await inventoryRepository.getInventoryItems()) ?? []
        var categories = ((try? await categoryRepository.all()) ?? []).filter { !$0.isDeleted }
        var count = 0
        for row in ready {
            var categoryId: String?
            if let name = row.category {
                if let match = categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    categoryId = match.id
                } else {
                    let category = ItemCategory(name: name, sortOrder: categories.count)
                    try? await categoryRepository.save(category)
                    categories.append(category)
                    categoryId = category.id
                }
            }
            var item = existing.first { ($0.barcode != nil && $0.barcode == row.barcode) || $0.name.caseInsensitiveCompare(row.name) == .orderedSame }
                ?? InventoryItem(name: row.name)
            let isNew = !existing.contains { $0.id == item.id }
            item.sellPrice = row.price
            if let stock = row.stock { item.currentStock = stock }
            if let barcode = row.barcode { item.barcode = barcode }
            if let cost = row.cost { item.costPrice = cost }
            if let categoryId { item.categoryId = categoryId }
            item.updatedAt = Date()
            do {
                if isNew { try await inventoryRepository.saveInventoryItem(item: item) } else { try await inventoryRepository.updateInventoryItem(item) }
                count += 1
            } catch {
                continue
            }
        }
        await audit?.log(.stock, action: "item.import", summary: "Imported \(count) items from \(fileName ?? "CSV")", targetId: nil)
        return count
    }
}
