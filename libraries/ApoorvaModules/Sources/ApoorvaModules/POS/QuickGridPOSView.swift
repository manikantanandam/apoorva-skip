//
//  QuickGridPOSView.swift
//  ApoorvaModules
//
//  The production-style POS: a grid of quick items with FIND, a half sheet to search items and a
//  half sheet to set MRP, quantity and discount. Shown when `POSConfig.layout == .quickGrid`.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct QuickGridPOSView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: POSViewModel
    private let config: POSConfig
    private let onAction: (POSAction) -> Void

    @State private var isShowingDatePicker = false

    public init(viewModel: POSViewModel, config: POSConfig, onAction: @escaping (POSAction) -> Void) {
        self.viewModel = viewModel
        self.config = config
        self.onAction = onAction
    }

    public var body: some View {
        ScreenScroll(spacing: ManiSpacing.md) {
            POSCustomerRow(viewModel: viewModel) { onAction(.pickCustomer) }
            if config.allowsWholesale {
                ManiSegmentedControl(selection: Binding(get: { viewModel.cart.priceTier ?? "retail" },
                                                        set: { viewModel.setPriceTier($0) }),
                                     options: [("retail", "Retail"), ("wholesale", "Wholesale")])
            }
            quickItems
            cart
        } bottom: {
            checkoutBar
        }
        .navigationTitle("New bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $isShowingDatePicker) {
            POSBillDatePicker(date: $viewModel.cart.billDateTime) { isShowingDatePicker = false }
        }
        .task { await viewModel.prepareData() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { isShowingDatePicker = true } label: {
                ManiSwiftUIComponents.IconView(.calendar, size: 18, color: theme.base.text)
            }
            .accessibilityLabel("Bill date & time")
            if config.allowsHold {
                Button { Task { await viewModel.holdCurrentBill() } } label: {
                    ManiSwiftUIComponents.IconView(.pause, size: 18, color: theme.base.text)
                }
                .disabled(viewModel.cart.items.isEmpty || viewModel.isHolding)
                .accessibilityLabel("Hold bill")
                Button { onAction(.openHeld) } label: {
                    ZStack(alignment: .topTrailing) {
                        ManiSwiftUIComponents.IconView(.tray, size: 18, color: theme.base.text)
                        if viewModel.heldBillsCount > 0 {
                            Circle().fill(theme.accent.accent).frame(width: 8, height: 8).offset(x: 4, y: -4)
                        }
                    }
                }
                .accessibilityLabel("Held bills (\(viewModel.heldBillsCount))")
            }
            Menu {
                Button("Scan barcode") { onAction(.scan) }
                Button("Quick item") { onAction(.customItem) }
                Button("Bill discount") { onAction(.discount) }
                if !viewModel.cart.items.isEmpty { Button("Clear bill", role: .destructive) { viewModel.clearCart() } }
            } label: {
                ManiSwiftUIComponents.IconView(.more, size: 18, color: theme.base.text)
            }
        }
    }

    // MARK: - Quick items

    @ViewBuilder private var quickItems: some View {
        SectionHeader(title: "Quick items")
        if viewModel.items.isEmpty {
            ManiEmptyState(icon: .box, title: "No items yet", message: "Bill it anyway as a quick item.",
                           actionTitle: "Quick item") { onAction(.customItem) }
        } else {
            // Plain rows instead of LazyVGrid: a lazy grid inside a height-fixed HStack sizes to its
            // content and leaves the tiles too narrow.
            HStack(alignment: .top, spacing: ManiSpacing.sm) {
                VStack(spacing: ManiSpacing.sm) {
                    ForEach(Array(quickRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: ManiSpacing.sm) {
                            ForEach(0..<Self.quickColumns, id: \.self) { column in
                                if column < row.count {
                                    let item = row[column]
                                    QuickItemTile(title: item.name, quantity: viewModel.quantity(of: item)) {
                                        onAction(viewModel.quickAction(for: item))
                                    }
                                } else {
                                    Color.clear.frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                findTile
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private static let quickColumns = 4

    /// Quick items split into rows of four; the last row is padded so tiles keep the same width.
    private var quickRows: [[InventoryItem]] {
        let items = viewModel.quickItems
        return stride(from: 0, to: items.count, by: Self.quickColumns).map {
            Array(items[$0..<min($0 + Self.quickColumns, items.count)])
        }
    }

    private var findTile: some View {
        Button { onAction(.find) } label: {
            VStack(spacing: ManiSpacing.xs) {
                // `ManiIconName.search` maps to a non-existent SF Symbol ("search"), so use the symbol directly.
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(theme.accent.on)
                Text("Find")
                    .font(theme.typography.secondary.weight(.semibold))
                    .foregroundStyle(theme.accent.on)
            }
            .frame(width: 64)
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: theme.radii.card).fill(theme.accent.accent))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Find item")
    }

    // MARK: - Cart

    private var itemsText: String {
        viewModel.cart.items.count == 1 ? "1 item" : "\(viewModel.cart.items.count) items"
    }

    @ViewBuilder private var cart: some View {
        if viewModel.cart.items.isEmpty {
            ManiEmptyState(icon: .cart, title: "Your cart is empty", message: "Add some items to start billing")
        } else {
            HStack(spacing: ManiSpacing.sm) {
                SectionHeader(title: "Current cart",
                              actionTitle: viewModel.cart.flatDiscount > 0 ? "Discount \(Money.format(viewModel.cart.flatDiscount))" : "Add discount",
                              action: { onAction(.discount) })
                ManiStatusBadge(itemsText, kind: .neutral)
            }
            ManiCard(padding: ManiSpacing.sm) {
                VStack(spacing: 0) {
                    ForEach(viewModel.cart.items) { line in
                        ManiCartLineRow(title: line.displayName,
                                        subtitle: lineSubtitle(line),
                                        totalText: Money.format(line.totalItemsPrice),
                                        quantityUnitText: line.weight == nil ? "\(line.quantity) × \(Money.format(line.finalPrice))/unit" : "",
                                        onTap: { onAction(.editLine(lineId: line.lineId)) },
                                        onRemove: { viewModel.removeLine(id: line.lineId) })
                    }
                }
            }
        }
    }

    private func lineSubtitle(_ line: CartItem) -> String {
        var parts = ["\(Money.format(line.mrp))/\(line.weight != nil ? line.unit ?? "kg" : "unit")"]
        if line.discountPercent > 0 { parts.append("\(Int(line.discountPercent.rounded()))% off") }
        return parts.joined(separator: " · ")
    }

    private var checkoutBar: some View {
        HStack(spacing: ManiSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(itemsText.uppercased())
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.base.textSecondary)
                Text(Money.format(viewModel.totalPayable))
                    .font(theme.typography.kpiValue)
                    .foregroundStyle(theme.base.text)
            }
            ManiButton("Proceed to checkout", isEnabled: !viewModel.cart.items.isEmpty) { onAction(.checkout) }
        }
        .padding(.top, ManiSpacing.sm)
        .background(theme.base.background)
    }
}

// MARK: - Tile

/// Name-only item tile with an accent strip and a quantity badge once it's on the bill.
struct QuickItemTile: View {
    @Environment(\.maniTheme) private var theme
    let title: String
    let quantity: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(theme.typography.secondary.weight(.medium))
                .foregroundStyle(theme.base.text)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(ManiSpacing.xs)
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(theme.base.surface)
                .overlay(alignment: .top) {
                    Rectangle().fill(theme.accent.accent).frame(height: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.card))
                .overlay(alignment: .topTrailing) {
                    if quantity > 0 { ManiStatusBadge("\(quantity)", kind: .success).padding(2) }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(quantity > 0 ? "\(title), \(quantity) on bill" : title)
    }
}

// MARK: - Find (half sheet)

public struct FindItemsSheet: View {
    private let viewModel: POSViewModel
    private let onSelect: (InventoryItem) -> Void
    private let onCustomItem: () -> Void
    @State private var query = ""

    public init(viewModel: POSViewModel, onSelect: @escaping (InventoryItem) -> Void, onCustomItem: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        self.onCustomItem = onCustomItem
    }

    public var body: some View {
        let results = viewModel.items(matching: query)
        ScreenScroll(spacing: ManiSpacing.md) {
            ManiSearchField(text: $query, placeholder: "Search items…")
            if results.isEmpty {
                ManiEmptyState(icon: .box, title: query.isEmpty ? "No items yet" : "No match",
                               message: "Bill it anyway as a quick item.", actionTitle: "Quick item", action: onCustomItem)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ManiSpacing.sm), count: 3),
                          spacing: ManiSpacing.sm) {
                    ForEach(results) { item in
                        QuickItemTile(title: item.name, quantity: viewModel.quantity(of: item)) { onSelect(item) }
                    }
                }
            }
        }
        .navigationTitle("Find item")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add / edit line (half sheet)

public struct QuickAddLineSheet: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: QuickAddLineViewModel
    private let onSave: (CartItem) -> Void
    private let onRemove: () -> Void

    public init(viewModel: QuickAddLineViewModel, onSave: @escaping (CartItem) -> Void, onRemove: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSave = onSave
        self.onRemove = onRemove
    }

    private var percentText: String {
        let percent = viewModel.discountPercent
        return percent == percent.rounded() ? "\(Int(percent))%" : String(format: "%.1f%%", percent)
    }

    public var body: some View {
        ScreenScroll(spacing: ManiSpacing.md) {
            HStack(alignment: .bottom, spacing: ManiSpacing.md) {
                ManiInputField(label: viewModel.original.weight == nil ? "MRP" : "MRP per \(viewModel.original.unit ?? "kg")",
                               text: $viewModel.mrpText, placeholder: "₹", keyboard: .decimal)
                if viewModel.original.weight == nil { quantityStepper }
            }
            ManiSegmentedControl(selection: Binding(get: { viewModel.mode }, set: { viewModel.setMode($0) }),
                                 options: QuickDiscountMode.allCases.map { ($0, $0.rawValue) })
            ManiInputField(label: viewModel.mode.fieldLabel, text: $viewModel.valueText,
                           placeholder: viewModel.mode == .percent ? "%" : "₹", keyboard: .decimal)
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Gross total", Money.format(viewModel.gross)),
                ManiKeyValue("Discount (\(percentText))", "−\(Money.format(viewModel.discount))"),
                ManiKeyValue("Net payable", Money.format(viewModel.net))
            ])
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton(viewModel.isNew ? "Add to bill" : "Update line", isEnabled: viewModel.isValid) {
                    onSave(viewModel.build())
                }
                if !viewModel.isNew {
                    ManiButton("Remove from bill", icon: .trash, kind: .outline, action: onRemove)
                }
            }
        }
        .navigationTitle(viewModel.isNew ? "Add \(viewModel.original.displayName)" : viewModel.original.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var quantityStepper: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.xs) {
            Text("Quantity")
                .font(theme.typography.secondary)
                .foregroundStyle(theme.base.textSecondary)
            HStack(spacing: ManiSpacing.sm) {
                stepButton(.minus, label: "Decrease quantity") { viewModel.decrement() }
                Text("\(viewModel.quantity)")
                    .font(theme.typography.body.weight(.semibold))
                    .foregroundStyle(theme.base.text)
                    .frame(minWidth: 28)
                stepButton(.plus, label: "Increase quantity") { viewModel.increment() }
            }
        }
    }

    private func stepButton(_ icon: ManiIconName, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ManiSwiftUIComponents.IconView(icon, size: 16, color: theme.base.text)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: theme.radii.chip).fill(theme.base.surface))
                .overlay(RoundedRectangle(cornerRadius: theme.radii.chip).stroke(theme.base.border))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
