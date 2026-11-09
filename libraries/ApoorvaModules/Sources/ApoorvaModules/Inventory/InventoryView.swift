//
//  InventoryView.swift
//  ApoorvaModules
//
//  Inventory (73), item (74), adjust (75), add/edit (76), categories (77), import (78).
//

import SwiftUI
import UniformTypeIdentifiers
import ApoorvaModels
import ManiSwiftUIComponents

// MARK: - List (73)

public struct InventoryView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable var viewModel: InventoryViewModel
    private let onSelect: (InventoryItem) -> Void
    private let onAdd: (() -> Void)?
    private let onMenu: (InventoryMenu) -> Void

    public enum InventoryMenu: Sendable { case categories, bulkImport, reorder, suppliers }

    public init(viewModel: InventoryViewModel, onSelect: @escaping (InventoryItem) -> Void = { _ in },
                onAdd: (() -> Void)? = nil, onMenu: @escaping (InventoryMenu) -> Void = { _ in }) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        self.onAdd = onAdd
        self.onMenu = onMenu
    }

    public var body: some View {
        ScreenScroll(spacing: ManiSpacing.md) {
            ScreenSubtitle(text: viewModel.subtitle)
            ManiSearchField(text: $viewModel.searchText, placeholder: "Search items or scan")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ManiSpacing.sm) {
                    ManiChip("All", isSelected: viewModel.filter == .all) { viewModel.filter = .all }
                    ManiChip("Low stock", isSelected: viewModel.filter == .low) { viewModel.filter = .low }
                    ManiChip("Out of stock", isSelected: viewModel.filter == .out) { viewModel.filter = .out }
                    ForEach(viewModel.categories) { category in
                        ManiChip(category.name, isSelected: viewModel.filter == .category(category.id)) { viewModel.filter = .category(category.id) }
                    }
                }
            }
            if viewModel.visible.isEmpty {
                ManiEmptyState(icon: .box, title: viewModel.items.isEmpty ? "No items yet" : "Nothing here",
                               message: viewModel.items.isEmpty ? "Add items one by one or import a CSV." : nil,
                               actionTitle: viewModel.items.isEmpty ? "Add item" : nil, action: viewModel.items.isEmpty ? onAdd : nil)
            } else {
                RowsCard {
                    ForEach(viewModel.visible) { item in
                        let status = viewModel.status(of: item)
                        ManiListRow(title: item.name,
                                    subtitle: [item.designCode ?? item.barcode.map { "SKU \($0)" }, viewModel.categoryName(item.categoryId)]
                                        .compactMap { $0 }.joined(separator: " · "),
                                    value: item.currentStock > 0 ? "\(item.currentStock) left" : "0",
                                    status: status.map { ($0.text, $0.isOut ? .error : .warning) }) { onSelect(item) }
                    }
                }
            }
        }
        .refreshable { await viewModel.forceSync() }
        .navigationTitle("Inventory")
        .toolbar {
            if let onAdd {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAdd) { ManiSwiftUIComponents.IconView(.plus, size: 18, color: theme.base.text) }
                        .accessibilityLabel("Add item")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Categories") { onMenu(.categories) }
                    Button("Import from CSV") { onMenu(.bulkImport) }
                    Button("Reorder low stock") { onMenu(.reorder) }
                    Button("Suppliers") { onMenu(.suppliers) }
                } label: {
                    ManiSwiftUIComponents.IconView(.more, size: 18, color: theme.base.text)
                }
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Item (74)

public struct InventoryItemView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: InventoryItemViewModel
    private let canEdit: Bool
    private let onAdjust: () -> Void
    private let onEdit: () -> Void

    public init(viewModel: InventoryItemViewModel, canEdit: Bool, onAdjust: @escaping () -> Void, onEdit: @escaping () -> Void) {
        self.viewModel = viewModel
        self.canEdit = canEdit
        self.onAdjust = onAdjust
        self.onEdit = onEdit
    }

    public var body: some View {
        ScreenScroll {
            if let item = viewModel.item {
                ScreenSubtitle(text: [item.designCode, viewModel.categoryName].compactMap { $0 }.joined(separator: " · "))
                RoundedRectangle(cornerRadius: theme.radii.card)
                    .fill(theme.accent.accent.opacity(0.1))
                    .frame(height: 140)
                    .overlay {
                        VStack(spacing: ManiSpacing.xs) {
                            if let url = item.imageURLs?.first.flatMap(URL.init(string:)) {
                                AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { ProgressView() }
                            } else {
                                ManiSwiftUIComponents.IconView(.box, size: 36, color: theme.accent.accent)
                            }
                            if let variants = viewModel.variantSummary { ScreenSubtitle(text: variants) }
                        }
                    }
                ManiKeyValueSummary(rows: [
                    ManiKeyValue("Price", item.sellPrice.map(Money.format) ?? "Not set"),
                    ManiKeyValue("Cost", item.costPrice.map(Money.format) ?? "Not set"),
                    ManiKeyValue("Stock", "\(item.currentStock)\(item.lowStockThreshold.map { " (low at \($0))" } ?? "")"),
                    ManiKeyValue("Barcode", item.barcode ?? "—")
                ], emphasizeLast: false)
                ManiBarChartCard(title: "Sold last 7 days", bars: viewModel.soldByDay.map { ManiChartDatum($0.label, $0.quantity) })
                if !viewModel.movements.isEmpty {
                    SectionHeader(title: "Stock movement")
                    RowsCard {
                        ForEach(viewModel.movements.prefix(10)) { movement in
                            ManiListRow(title: movement.reason.title, subtitle: movement.createdAt.formatted(date: .abbreviated, time: .shortened),
                                        value: (movement.delta > 0 ? "+" : "") + String(Int(movement.delta)))
                        }
                    }
                }
            } else {
                ProgressView()
            }
        } bottom: {
            if canEdit && viewModel.item != nil { ManiButton("Adjust stock", action: onAdjust) }
        }
        .navigationTitle(viewModel.item?.name ?? "Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit", action: onEdit)
                }
            }
        }
        .task { await viewModel.load() }
    }
}

extension StockMovementReason {
    var title: String {
        switch self {
        case .sale: "Sold"
        case .purchase: "Purchase"
        case .purchaseReturn: "Returned to supplier"
        case .customerReturn: "Customer return"
        case .cancel: "Bill cancelled"
        case .adjustment: "Count fix"
        case .damage: "Damage"
        case .opening: "Opening stock"
        }
    }
}

// MARK: - Adjust (75)

public struct StockAdjustView: View {
    @Bindable private var viewModel: StockAdjustViewModel
    private let onDone: () -> Void

    public init(viewModel: StockAdjustViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(viewModel.item?.name ?? "") · now \(viewModel.current)")
            ManiSegmentedControl(selection: $viewModel.mode, options: StockAdjustViewModel.Mode.allCases.map { ($0, $0.rawValue) })
            ManiHeroAmount(viewModel.heroText, caption: "new stock \(viewModel.newStock)")
            FlowLayout {
                ForEach(StockAdjustViewModel.Reason.allCases, id: \.self) { reason in
                    ManiChip(reason.rawValue, isSelected: viewModel.reason == reason) { viewModel.reason = reason }
                }
            }
            ManiKeypad(showsDecimal: false) { key in viewModel.quantityText = key.apply(to: viewModel.quantityText, maxDecimals: 0, maxLength: 6) }
            if viewModel.newStock < 0 { ManiNote("That leaves stock below zero.", kind: .warning) }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save", isLoading: viewModel.isSaving, isEnabled: viewModel.canSave) {
                Task { if await viewModel.save() { onDone() } }
            }
        }
        .navigationTitle("Adjust stock")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - Add / edit (76)

public struct ItemFormView: View {
    @Bindable private var viewModel: ItemFormViewModel
    private let showsWholesale: Bool
    private let showsWarranty: Bool
    private let onSaved: (InventoryItem) -> Void
    private let onDeleted: () -> Void

    public init(viewModel: ItemFormViewModel, showsWholesale: Bool, showsWarranty: Bool,
                onSaved: @escaping (InventoryItem) -> Void, onDeleted: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.showsWholesale = showsWholesale
        self.showsWarranty = showsWarranty
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Only name and price are required")
            ManiInputField(label: "Name", text: $viewModel.name, placeholder: "Kids Watch")
            ManiInputField(label: "Retail price", text: $viewModel.priceText, placeholder: "₹", keyboard: .decimal)
            if showsWholesale {
                ManiInputField(label: "Wholesale price (optional)", text: $viewModel.wholesaleText, placeholder: "₹", keyboard: .decimal)
            }
            SectionHeader(title: "Sold as")
            ManiSegmentedControl(selection: $viewModel.soldAs, options: ItemFormViewModel.SoldAs.allCases.map { ($0, $0.rawValue) })
            ManiInputField(label: "Stock", text: $viewModel.stockText, placeholder: viewModel.soldAs == .kg ? "kg" : "pieces", keyboard: .number)
            if showsWarranty {
                ManiToggleRow(title: "Has warranty", subtitle: "Shown on bill and receipt", isOn: $viewModel.hasWarranty)
                if viewModel.hasWarranty {
                    FlowLayout {
                        ForEach(["6", "12", "24"], id: \.self) { value in
                            ManiChip(value, isSelected: viewModel.warrantyValueText == value) { viewModel.warrantyValueText = value }
                        }
                    }
                    ManiInputField(label: "Warranty period", text: $viewModel.warrantyValueText, keyboard: .number)
                    ManiSegmentedControl(selection: $viewModel.warrantyUnit, options: ItemFormViewModel.WarrantyUnit.allCases.map { ($0, $0.rawValue) })
                }
            }
            ManiToggleRow(title: "Has variants", subtitle: "Size or colour", isOn: $viewModel.hasVariants)
            if viewModel.hasVariants {
                ManiInputField(label: "Sizes (comma separated)", text: $viewModel.sizesText, placeholder: "2.2, 2.4, 2.6")
                ManiInputField(label: "Colours (comma separated)", text: $viewModel.coloursText, placeholder: "Ruby, Emerald, Gold")
            }
            ManiButton(viewModel.showsMore ? "Fewer details" : "More: barcode, cost, category, design code", kind: .outline) {
                viewModel.showsMore.toggle()
            }
            if viewModel.showsMore {
                ManiInputField(label: "Barcode", text: $viewModel.barcode, keyboard: .number)
                ManiInputField(label: "Cost price", text: $viewModel.costText, placeholder: "₹", keyboard: .decimal)
                ManiInputField(label: "Design code", text: $viewModel.designCode, placeholder: "ER-204")
                ManiInputField(label: "Low stock at", text: $viewModel.lowStockText, placeholder: "5", keyboard: .number)
                if !viewModel.categories.isEmpty {
                    SectionHeader(title: "Category")
                    FlowLayout {
                        ManiChip("None", isSelected: viewModel.categoryId == nil) { viewModel.categoryId = nil }
                        ForEach(viewModel.categories) { category in
                            ManiChip(category.name, isSelected: viewModel.categoryId == category.id) { viewModel.categoryId = category.id }
                        }
                    }
                }
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save item", isLoading: viewModel.isSaving, isEnabled: viewModel.canSave) {
                Task { if let item = await viewModel.save() { onSaved(item) } }
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit item" : "New item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isEditing {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Delete item", role: .destructive) { Task { if await viewModel.delete() { onDeleted() } } }
                    } label: {
                        ManiSwiftUIComponents.IconView(.more, size: 18, color: .primary)
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Categories (77)

public struct CategoriesView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CategoriesViewModel
    @State private var renaming: ItemCategory?
    @State private var renameText = ""

    public init(viewModel: CategoriesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        List {
            Section {
                HStack {
                    TextField("New category", text: $viewModel.newName)
                    Button("Add") { Task { await viewModel.add() } }
                        .disabled(viewModel.newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Drag to reorder billing chips") {
                ForEach(viewModel.categories) { category in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name).font(theme.typography.body.weight(.medium))
                            Text("\(viewModel.counts[category.id] ?? 0) items").font(theme.typography.secondary)
                                .foregroundStyle(theme.base.textSecondary)
                        }
                        Spacer()
                        ManiSwiftUIComponents.IconView(.drag, size: 14, color: theme.base.textSecondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        renameText = category.name
                        renaming = category
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { Task { await viewModel.delete(category) } }
                    }
                }
                .onMove { source, destination in Task { await viewModel.move(from: source, to: destination) } }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.base.background.ignoresSafeArea())
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Categories")
        .alert("Rename category", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let renaming { Task { await viewModel.rename(renaming, to: renameText) } }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Import (78)

public struct ItemImportView: View {
    @Bindable private var viewModel: ItemImportViewModel
    private let onDone: (Int) -> Void
    @State private var isPicking = false

    public init(viewModel: ItemImportViewModel, onDone: @escaping (Int) -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            if let csv = viewModel.csv {
                ManiEmptyState(icon: .upload, title: "\(viewModel.fileName ?? "items.csv") · \(csv.rows.count) rows",
                               message: "Columns matched automatically")
                ManiKeyValueSummary(rows: ["name", "category", "price", "stock", "barcode", "cost"].map { key in
                    ManiKeyValue(key.capitalized, csv.columns[key].map { "Column \(Character(UnicodeScalar(65 + $0)!))" } ?? "Not found")
                }, emphasizeLast: false)
                RowsCard {
                    ManiListRow(title: "Ready to add", subtitle: "\(viewModel.ready.count) items", status: ("Ready", .success))
                    if !viewModel.needsAttention.isEmpty {
                        ManiListRow(title: "Need attention", subtitle: "\(viewModel.needsAttention.count) rows · missing name or price",
                                    status: ("Fix", .warning))
                    }
                }
                if !viewModel.needsAttention.isEmpty {
                    ScreenSubtitle(text: "Rows " + viewModel.needsAttention.prefix(8).map { String($0.line) }.joined(separator: ", ")
                                   + (viewModel.needsAttention.count > 8 ? "…" : "") + " will be skipped.")
                }
            } else {
                ManiEmptyState(icon: .upload, title: "Pick a CSV file",
                               message: "Name and Price are needed. Category, Stock, Barcode and Cost are optional. Save Excel sheets as CSV first.",
                               actionTitle: "Choose file") { isPicking = true }
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .warning) }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                if viewModel.csv != nil {
                    ManiButton("Import \(viewModel.ready.count) items", isLoading: viewModel.isImporting, isEnabled: !viewModel.ready.isEmpty) {
                        Task { onDone(await viewModel.importReady()) }
                    }
                }
                ShareLink(item: ItemCSV.template, preview: SharePreview("items-template.csv")) {
                    Text("Download template").frame(maxWidth: .infinity, minHeight: ManiTouchTarget.minimum)
                }
            }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                viewModel.read(text: text, fileName: url.lastPathComponent)
            } else {
                viewModel.errorMessage = "Couldn't read that file."
            }
        }
        .navigationTitle("Import items")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.csv != nil {
                ToolbarItem(placement: .topBarTrailing) { Button("Change file") { isPicking = true } }
            }
        }
    }
}
