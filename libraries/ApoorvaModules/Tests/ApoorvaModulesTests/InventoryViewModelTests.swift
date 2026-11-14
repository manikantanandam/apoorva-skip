//
//  InventoryViewModelTests.swift
//  ApoorvaModules
//

import Testing
import Foundation
import ApoorvaModels
import ApoorvaRepository
@testable import ApoorvaModules

private final class RecordingInventoryRepository: InventoryItemRepositoryProtocol, @unchecked Sendable {
    var items: [InventoryItem]
    var saved: [InventoryItem] = []
    var updated: [InventoryItem] = []
    var deletedIds: [String] = []
    var syncForced = false
    var failWrites = false

    init(_ items: [InventoryItem] = []) { self.items = items }

    func getInventoryItems() async throws -> [InventoryItem] { items }
    func saveInventoryItem(item: InventoryItem) async throws {
        if failWrites { throw NSError(domain: "test", code: 1) }
        saved.append(item)
    }
    func updateInventoryItem(_ item: InventoryItem) async throws {
        if failWrites { throw NSError(domain: "test", code: 1) }
        updated.append(item)
    }
    func deleteInventoryItem(id: String) async throws {}
    func markAsDeleted(id: String) async throws {
        if failWrites { throw NSError(domain: "test", code: 1) }
        deletedIds.append(id)
    }
    func sync(force: Bool) async throws { syncForced = force }
    func lastSyncedAt() async throws -> Date? { nil }
}

private final class RecordingAudit: AuditLogging, @unchecked Sendable {
    var actions: [String] = []
    func log(_ category: AuditCategory, action: String, summary: String, targetId: String?) async { actions.append(action) }
}

private final class AdjustingStock: StockRepositoryProtocol, @unchecked Sendable {
    var fail = false
    var lastAdjustment: StockAdjustment?
    func adjust(itemId: String, _ adjustment: StockAdjustment, reason: StockMovementReason, note: String?, by actorId: String) async throws -> InventoryItem {
        if fail { throw NSError(domain: "test", code: 1) }
        lastAdjustment = adjustment
        return InventoryItem(id: itemId, name: "Adjusted", currentStock: 42)
    }
    func recordPurchase(_ purchase: Purchase, by actorId: String) async throws {}
    func paySupplier(_ supplier: Supplier, amount: Double, mode: String, by actorId: String) async throws {}
}

private func item(_ id: String, _ name: String, stock: Int, category: String? = nil, barcode: String? = nil) -> InventoryItem {
    var item = InventoryItem(id: id, name: name, currentStock: stock)
    item.categoryId = category
    item.barcode = barcode
    item.sellPrice = 100
    return item
}

@MainActor
struct InventoryListViewModelTests {
    private func makeModel() async -> InventoryViewModel {
        let repo = RecordingInventoryRepository([
            item("1", "Bangle", stock: 20, category: "c1", barcode: "111"),
            item("2", "Chain", stock: 2, category: "c2"),
            item("3", "Ring", stock: 0)
        ])
        let categories = StubOrgRepository<ItemCategory>([ItemCategory(id: "c2", name: "Chains", sortOrder: 1),
                                                           ItemCategory(id: "c1", name: "Bangles", sortOrder: 0)])
        let model = InventoryViewModel(inventoryRepository: repo, categoryRepository: categories)
        await model.load()
        return model
    }

    @Test func loadSortsCategoriesAndCountsStockStates() async {
        let model = await makeModel()
        #expect(model.items.count == 3)
        #expect(model.categories.map(\.name) == ["Bangles", "Chains"])
        #expect(model.lowCount == 1)
        #expect(model.outCount == 1)
        #expect(model.subtitle == "3 items · 2 low")
        #expect(model.categoryName("c1") == "Bangles")
        #expect(model.categoryName("zzz") == "zzz")
        #expect(model.categoryName(nil) == nil)
    }

    @Test func filtersAndSearchNarrowVisibleItems() async {
        let model = await makeModel()
        model.filter = .low
        #expect(model.visible.map(\.id) == ["2"])
        model.filter = .out
        #expect(model.visible.map(\.id) == ["3"])
        model.filter = .category("c1")
        #expect(model.visible.map(\.id) == ["1"])
        model.filter = .all
        model.searchText = " 111 "
        #expect(model.visible.map(\.id) == ["1"])
        model.searchText = "ring"
        #expect(model.visible.map(\.id) == ["3"])
    }

    @Test func statusLabelsOutAndLow() async {
        let model = await makeModel()
        #expect(model.status(of: item("a", "x", stock: 0))?.isOut == true)
        #expect(model.status(of: item("b", "x", stock: 3))?.text == "Low")
        #expect(model.status(of: item("c", "x", stock: 50)) == nil)
    }

    @Test func forceSyncReloads() async {
        let repo = RecordingInventoryRepository([item("1", "A", stock: 10)])
        let model = InventoryViewModel(inventoryRepository: repo)
        await model.forceSync()
        #expect(repo.syncForced)
        #expect(model.items.count == 1)
    }
}

@MainActor
struct StockAdjustViewModelTests {
    private func makeModel(stock: AdjustingStock = AdjustingStock()) async -> (StockAdjustViewModel, AdjustingStock) {
        let repo = RecordingInventoryRepository([item("1", "Bangle", stock: 10)])
        let model = StockAdjustViewModel(itemId: "1", inventoryRepository: repo, stock: stock, actorId: "u1")
        await model.load()
        return (model, stock)
    }

    @Test func modesComputeNewStockAndHero() async {
        let (model, _) = await makeModel()
        model.quantityText = "4"
        #expect(model.newStock == 14 && model.heroText == "+4")
        model.mode = .remove
        #expect(model.newStock == 6 && model.heroText == "−4")
        model.mode = .exact
        #expect(model.newStock == 4 && model.heroText == "4")
    }

    @Test func canSaveRequiresChange() async {
        let (model, _) = await makeModel()
        #expect(!model.canSave)
        model.quantityText = "3"
        #expect(model.canSave)
        model.mode = .exact
        model.quantityText = "10"
        #expect(!model.canSave)
    }

    @Test func saveAppliesAdjustmentAndUpdatesItem() async {
        let (model, stock) = await makeModel()
        model.quantityText = "5"
        model.reason = .damage
        #expect(await model.save())
        #expect(model.item?.currentStock == 42)
        if case .add(let amount)? = stock.lastAdjustment { #expect(amount == 5) } else { Issue.record("expected add") }
    }

    @Test func saveFailureSetsError() async {
        let stock = AdjustingStock()
        stock.fail = true
        let (model, _) = await makeModel(stock: stock)
        model.quantityText = "5"
        #expect(await model.save() == false)
        #expect(model.errorMessage != nil)
        model.quantityText = ""
        #expect(await model.save() == false)
    }

    @Test func reasonsMapToMovementReasons() {
        for reason in StockAdjustViewModel.Reason.allCases { _ = reason.movementReason }
        #expect(StockAdjustViewModel.Reason.countFix.movementReason == .adjustment)
    }
}

@MainActor
struct ItemFormViewModelTests {
    private func makeModel(_ id: String?, repo: RecordingInventoryRepository, audit: RecordingAudit? = nil) -> ItemFormViewModel {
        ItemFormViewModel(itemId: id, inventoryRepository: repo, categoryRepository: StubOrgRepository<ItemCategory>(), audit: audit)
    }

    @Test func saveRequiresNameAndPrice() async {
        let model = makeModel(nil, repo: RecordingInventoryRepository())
        #expect(await model.save() == nil)
        #expect(model.errorMessage == "Name and price are required.")
    }

    @Test func savesNewItemWithAuditAndWarrantyAndVariants() async throws {
        let repo = RecordingInventoryRepository()
        let audit = RecordingAudit()
        let model = makeModel(nil, repo: repo, audit: audit)
        model.name = " Watch "
        model.priceText = "999"
        model.soldAs = .pack
        model.stockText = "7"
        model.hasWarranty = true
        model.warrantyValueText = "2"
        model.warrantyUnit = .years
        model.hasVariants = true
        model.sizesText = "S, M"
        model.coloursText = "Red, Blue"
        model.barcode = "123"
        model.designCode = "D1"
        model.lowStockText = "3"
        let saved = try #require(await model.save())
        #expect(saved.name == "Watch")
        #expect(saved.unit == "pack")
        #expect(saved.currentStock == 7)
        #expect(saved.warrantyMonths == 24)
        #expect(saved.variantsJSON != nil)
        #expect(saved.barcode == "123" && saved.lowStockThreshold == 3)
        #expect(repo.saved.count == 1)
        #expect(audit.actions == ["item.add"])
    }

    @Test func warrantyDaysRoundUpAndInvalidIsNil() {
        let model = makeModel(nil, repo: RecordingInventoryRepository())
        #expect(model.warrantyMonths == nil)
        model.hasWarranty = true
        model.warrantyUnit = .days
        model.warrantyValueText = "45"
        #expect(model.warrantyMonths == 2)
        model.warrantyValueText = "x"
        #expect(model.warrantyMonths == nil)
        model.hasVariants = true
        #expect(model.variantsJSON == nil)
    }

    @Test func editLoadsExistingItemAndUpdatesAndDeletes() async throws {
        var existing = item("1", "Bangle", stock: 9, category: "c1", barcode: "55")
        existing.warrantyMonths = 12
        existing.unit = "kg"
        existing.costPrice = 40.5
        let repo = RecordingInventoryRepository([existing])
        let audit = RecordingAudit()
        let model = makeModel("1", repo: repo, audit: audit)
        await model.load()
        #expect(model.isEditing)
        #expect(model.name == "Bangle")
        #expect(model.soldAs == .kg)
        #expect(model.warrantyUnit == .years && model.warrantyValueText == "1")
        #expect(model.costText == "40.5" && model.priceText == "100")
        model.name = "Bangle 2"
        #expect(try #require(await model.save()).name == "Bangle 2")
        #expect(repo.updated.count == 1)
        #expect(await model.delete())
        #expect(repo.deletedIds == ["1"])
        #expect(audit.actions == ["item.edit", "item.delete"])
    }

    @Test func failuresSurfaceErrors() async {
        let repo = RecordingInventoryRepository()
        repo.failWrites = true
        let model = makeModel(nil, repo: repo)
        model.name = "A"
        model.priceText = "10"
        #expect(await model.save() == nil)
        #expect(model.errorMessage == "Couldn't save the item. Try again.")
        #expect(await model.delete() == false)

        let editRepo = RecordingInventoryRepository([item("1", "A", stock: 1)])
        let editModel = makeModel("1", repo: editRepo)
        await editModel.load()
        editRepo.failWrites = true
        #expect(await editModel.delete() == false)
        #expect(editModel.errorMessage == "Couldn't delete the item.")
    }

    @Test func soldAsMapsUnits() {
        #expect(ItemFormViewModel.SoldAs.from("g") == .kg)
        #expect(ItemFormViewModel.SoldAs.from("m") == .metre)
        #expect(ItemFormViewModel.SoldAs.from(nil) == .piece)
        #expect(ItemFormViewModel.SoldAs.metre.unit == "m")
        #expect(ItemFormViewModel.text(2.5) == "2.5")
    }
}

@MainActor
struct CategoriesAndImportTests {
    @Test func categoriesAddRenameMoveDelete() async {
        let repo = StubOrgRepository<ItemCategory>([ItemCategory(id: "a", name: "A", sortOrder: 0), ItemCategory(id: "b", name: "B", sortOrder: 1)])
        let inventory = RecordingInventoryRepository([item("1", "x", stock: 1, category: "a")])
        let model = CategoriesViewModel(repository: repo, inventoryRepository: inventory)
        await model.load()
        #expect(model.counts["a"] == 1)

        model.newName = "a"
        await model.add()
        #expect(model.categories.count == 2)
        model.newName = "C"
        await model.add()
        #expect(model.categories.map(\.name) == ["A", "B", "C"])

        await model.rename(model.categories[0], to: "  Alpha ")
        #expect(model.categories[0].name == "Alpha")
        await model.rename(model.categories[0], to: "  ")
        #expect(model.categories[0].name == "Alpha")

        await model.move(from: IndexSet(integer: 2), to: 0)
        #expect(model.categories.first?.name == "C")

        await model.delete(model.categories[0])
        #expect(model.categories.count == 2)
    }

    @Test func importAddsAndUpdatesRows() async {
        let existing = item("1", "Bangle", stock: 1)
        let repo = RecordingInventoryRepository([existing])
        let audit = RecordingAudit()
        let categories = StubOrgRepository<ItemCategory>()
        let model = ItemImportViewModel(inventoryRepository: repo, categoryRepository: categories, audit: audit)
        model.read(text: "Name,Category,Price,Stock,Barcode,Cost\nBangle,Fancy,150,5,999,80\nNew,Fancy,20,,,\nBad,,0,,,\n", fileName: "items.csv")
        #expect(model.errorMessage == nil)
        #expect(model.ready.count == 2)
        #expect(model.needsAttention.count == 1)
        #expect(await model.importReady() == 2)
        #expect(repo.updated.count == 1)
        #expect(repo.saved.count == 1)
        #expect(categories.documents.count == 1)
        #expect(audit.actions == ["item.import"])
    }

    @Test func importRejectsFilesWithoutRequiredColumns() {
        let model = ItemImportViewModel(inventoryRepository: RecordingInventoryRepository(), categoryRepository: StubOrgRepository<ItemCategory>(), audit: nil)
        model.read(text: "Foo,Bar\n1,2\n", fileName: "x.csv")
        #expect(model.errorMessage != nil)
    }
}
