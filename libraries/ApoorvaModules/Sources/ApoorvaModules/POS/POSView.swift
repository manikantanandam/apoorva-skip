//
//  POSView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 07/10/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// Where a POS tap should go; the coordinator maps each case to a route or sheet.
public enum POSAction: Equatable, Sendable {
    case pickCustomer
    case openHeld
    case checkout
    case scan
    case customItem
    case discount
    case packages
    case catalogShare
    case editLine(lineId: String)
    case newLine(itemId: String)
    case weigh(itemId: String)
    case variant(itemId: String)
    case itemDetail(itemId: String)
}

/// What this shop's POS shows; resolved from the vertical, flags and permissions.
public struct POSConfig: Sendable {
    public var style: BillingStyle
    public var allowsCalculator: Bool
    public var allowsWholesale: Bool
    public var tracksCommission: Bool
    public var sellsPackages: Bool
    public var allowsHold: Bool
    public var counterName: String

    public init(style: BillingStyle, allowsCalculator: Bool = false, allowsWholesale: Bool = false,
                tracksCommission: Bool = false, sellsPackages: Bool = false, allowsHold: Bool = true,
                counterName: String = "") {
        self.style = style
        self.allowsCalculator = allowsCalculator
        self.allowsWholesale = allowsWholesale
        self.tracksCommission = tracksCommission
        self.sellsPackages = sellsPackages
        self.allowsHold = allowsHold
        self.counterName = counterName
    }
}

/// New bill (designs 26 kirana, 29 calculator, 30 fancy, 35 jewellery, 38 parlour, 41 wholesale).
public struct POSView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: POSViewModel
    private let config: POSConfig
    private let onAction: (POSAction) -> Void

    @State private var isShowingDatePicker = false
    @State private var parlourTab = ParlourTab.services

    enum ParlourTab: String, CaseIterable { case services = "Services", packages = "Packages", products = "Products" }

    public init(viewModel: POSViewModel, config: POSConfig, onAction: @escaping (POSAction) -> Void) {
        self.viewModel = viewModel
        self.config = config
        self.onAction = onAction
    }

    private var subtitle: String {
        if let name = viewModel.cart.customerName, !name.isEmpty {
            return viewModel.isWholesale ? "\(name) · wholesale buyer" : name
        }
        return config.counterName.isEmpty ? "Walk-in customer" : config.counterName
    }

    public var body: some View {
        ScreenScroll(spacing: ManiSpacing.md) {
            customerRow
            if config.allowsWholesale {
                ManiSegmentedControl(selection: Binding(get: { viewModel.cart.priceTier ?? "retail" },
                                                        set: { viewModel.setPriceTier($0) }),
                                     options: [("retail", "Retail"), ("wholesale", "Wholesale")])
            }
            if viewModel.isCalculatorMode {
                calculator
            } else {
                browse
            }
            cartLines
        } bottom: {
            if !viewModel.cart.items.isEmpty {
                ManiActionBar(summaryText: cartSummary,
                              primaryTitle: "Charge \(Money.format(viewModel.totalPayable))",
                              primaryAction: { onAction(.checkout) },
                              secondaryTitle: config.allowsHold ? "Hold" : nil,
                              secondaryAction: config.allowsHold ? { Task { await viewModel.holdCurrentBill() } } : nil)
            }
        }
        .navigationTitle(config.style == .catalog ? "Catalog" : "New bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: $isShowingDatePicker) { datePicker }
        .tipsOverlay(screen: "pos.\(config.style.rawValue)", tips: tips)
        .task { await viewModel.prepareData() }
    }

    // MARK: - Header

    private var customerRow: some View {
        RowsCard {
            NavRow(icon: .customer, title: subtitle,
                   subtitle: viewModel.customer.map { $0.dueBalance > 0 ? "\($0.phone) · dues \(Money.format($0.dueBalance))" : $0.phone }
                       ?? "Tap to attach a customer",
                   action: { onAction(.pickCustomer) })
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if config.allowsCalculator {
                Button { viewModel.isCalculatorMode.toggle() } label: {
                    ManiSwiftUIComponents.IconView(viewModel.isCalculatorMode ? .list : .grid, size: 18, color: theme.base.text)
                }
                .accessibilityLabel(viewModel.isCalculatorMode ? "Item list" : "Quick bill")
            }
            Menu {
                Button("Scan barcode") { onAction(.scan) }
                Button("Quick item") { onAction(.customItem) }
                Button("Bill discount") { onAction(.discount) }
                if config.style == .catalog { Button("Share catalog") { onAction(.catalogShare) } }
                Button("Bill date & time") { isShowingDatePicker = true }
                if config.allowsHold { Button("Held bills (\(viewModel.heldBillsCount))") { onAction(.openHeld) } }
                if !viewModel.cart.items.isEmpty { Button("Clear bill", role: .destructive) { viewModel.clearCart() } }
            } label: {
                ZStack(alignment: .topTrailing) {
                    ManiSwiftUIComponents.IconView(.more, size: 18, color: theme.base.text)
                    if viewModel.heldBillsCount > 0 {
                        Circle().fill(theme.accent.accent).frame(width: 8, height: 8).offset(x: 4, y: -4)
                    }
                }
            }
        }
    }

    private var datePicker: some View {
        NavigationStack {
            DatePicker("Bill date & time", selection: $viewModel.cart.billDateTime)
                .datePickerStyle(.graphical)
                .padding(ManiSpacing.lg)
                .navigationTitle("Bill date & time")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isShowingDatePicker = false }
                    }
                }
        }
        .presentationDetents([.medium])
    }

    private var tips: [String] {
        switch config.style {
        case .tileGrid: ["Tap an item to add it. Tap again to add one more. Long-press to change price or quantity.",
                         "Items with sizes or colours open a picker.", "Hold a bill to serve the next customer."]
        case .searchList: ["Search or scan to add. Loose items ask for weight.", "Not in your list? Use Quick item from ⋯."]
        case .catalog: ["Search by design code, e.g. ER-204.", "Tap a design to see photos and share it."]
        case .services: ["Pick who did the service so commission adds up.", "Packages tab sells and uses sessions."]
        }
    }

    // MARK: - Browsing

    @ViewBuilder private var browse: some View {
        if config.style == .services {
            ManiSegmentedControl(selection: $parlourTab, options: ParlourTab.allCases.map { ($0, $0.rawValue) })
            if parlourTab == .packages {
                ManiButton("Open packages", icon: .gift, kind: .outline) { onAction(.packages) }
            }
        }
        ManiSearchField(text: $viewModel.searchText, placeholder: searchPlaceholder)
        if viewModel.searchText.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ManiSpacing.sm) {
                    ForEach(viewModel.categoryOptions, id: \.title) { option in
                        ManiChip(option.title, isSelected: viewModel.categoryFilter == option.id) {
                            viewModel.categoryFilter = option.id
                        }
                    }
                }
            }
        }
        if viewModel.visibleItems.isEmpty {
            ManiEmptyState(icon: .box, title: viewModel.searchText.isEmpty ? "No items yet" : "No match",
                           message: "Bill it anyway as a quick item.", actionTitle: "Quick item") { onAction(.customItem) }
        } else {
            switch config.style {
            case .searchList: itemRows
            case .tileGrid: tileGrid(columns: 3)
            case .catalog: catalogGrid
            case .services:
                if parlourTab != .packages { itemRows }
            }
        }
        if config.style == .services && config.tracksCommission && !viewModel.staff.isEmpty {
            SectionHeader(title: "Done by (optional, for commission)")
            FlowLayout {
                ForEach(viewModel.staff) { member in
                    ManiChip(member.name, isSelected: viewModel.doneBy?.id == member.id) { viewModel.doneBy = member }
                }
                ManiChip("Skip", isSelected: viewModel.doneBy == nil) { viewModel.doneBy = nil }
            }
        }
    }

    private var searchPlaceholder: String {
        switch config.style {
        case .searchList: "Search item or scan"
        case .tileGrid: "Search or scan barcode"
        case .catalog: "Design code e.g. ER-204"
        case .services: "Search services"
        }
    }

    private func tap(_ item: InventoryItem) {
        switch viewModel.tap(item) {
        case .added: break
        case .needsPrice(let id): onAction(.newLine(itemId: id))
        case .needsWeight(let id): onAction(.weigh(itemId: id))
        case .needsVariant(let id): onAction(.variant(itemId: id))
        }
    }

    private func priceText(_ item: InventoryItem) -> String {
        guard let price = viewModel.price(of: item) else { return "Set price" }
        if viewModel.isLoose(item) { return "\(Money.format(price))/\(item.unit ?? "kg")" }
        if viewModel.isWholesale, item.wholesalePrice != nil, let retail = item.sellPrice {
            return "Wholesale \(Money.format(price)) · retail \(Money.format(retail))"
        }
        return Money.format(price)
    }

    private var itemRows: some View {
        RowsCard {
            ForEach(viewModel.visibleItems) { item in
                let qty = viewModel.quantity(of: item)
                ManiListRow(title: item.name,
                            subtitle: config.style == .services ? priceText(item) : "\(priceText(item)) · stock \(item.currentStock)",
                            value: qty > 0 ? "× \(qty)" : "+",
                            action: { tap(item) })
            }
        }
    }

    private func tileGrid(columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ManiSpacing.sm), count: columns),
                  spacing: ManiSpacing.sm) {
            ForEach(viewModel.visibleItems) { item in
                ManiItemTile(imageURL: item.imageURLs?.first.flatMap(URL.init(string:)),
                             title: item.name, priceText: priceText(item),
                             quantity: viewModel.quantity(of: item),
                             onIncrement: { tap(item) },
                             onDecrement: { viewModel.decrement(item) })
                    .onLongPressGesture {
                        if let line = viewModel.cart.items.first(where: { $0.category.id == item.id }) {
                            onAction(.editLine(lineId: line.lineId))
                        } else {
                            onAction(.newLine(itemId: item.id))
                        }
                    }
            }
        }
    }

    private var catalogGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: ManiSpacing.sm), GridItem(.flexible())], spacing: ManiSpacing.sm) {
            ForEach(viewModel.visibleItems) { item in
                Button { onAction(.itemDetail(itemId: item.id)) } label: {
                    ManiCard {
                        VStack(alignment: .leading, spacing: ManiSpacing.xs) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: theme.radii.chip)
                                    .fill(theme.accent.accent.opacity(0.12))
                                    .frame(height: 96)
                                    .overlay(ManiSwiftUIComponents.IconView(.sparkles, size: 28, color: theme.accent.accent))
                                let qty = viewModel.quantity(of: item)
                                if qty > 0 { ManiStatusBadge("\(qty)", kind: .success).padding(4) }
                            }
                            Text(item.name)
                                .font(theme.typography.body.weight(.medium))
                                .foregroundStyle(theme.base.text)
                                .lineLimit(1)
                            Text([item.designCode, viewModel.price(of: item).map(Money.format)].compactMap { $0 }.joined(separator: " · "))
                                .font(theme.typography.secondary)
                                .foregroundStyle(theme.base.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Calculator mode (design 29)

    @ViewBuilder private var calculator: some View {
        ScreenSubtitle(text: "Easy mode · bill by amount, no item list")
        ManiHeroAmount(viewModel.calculatorText.isEmpty ? "₹0" : "₹" + viewModel.calculatorText,
                       caption: "Next amount · tap a category to name it")
        FlowLayout {
            ForEach(["Misc", "Grocery", "Snacks", "Dairy"], id: \.self) { category in
                ManiChip(category, isSelected: viewModel.calculatorCategory == category) { viewModel.calculatorCategory = category }
            }
        }
        ManiKeypad { key in
            switch key {
            case .digit(let value): viewModel.calculatorKey("\(value)")
            case .decimal: viewModel.calculatorKey(".")
            case .backspace: viewModel.calculatorKey("⌫")
            }
        }
        ManiButton("Add amount", icon: .plus, kind: .secondary, isEnabled: (Double(viewModel.calculatorText) ?? 0) > 0) {
            viewModel.addCalculatorAmount()
        }
    }

    // MARK: - Cart

    private var cartSummary: String {
        let lines = viewModel.cart.items.count
        var text = lines == 1 ? "1 item" : "\(lines) items"
        if viewModel.cart.flatDiscount > 0 { text += " · −\(Money.format(viewModel.cart.flatDiscount))" }
        if let name = viewModel.cart.customerName, !name.isEmpty { text += " · \(name)" }
        return text
    }

    @ViewBuilder private var cartLines: some View {
        if !viewModel.cart.items.isEmpty {
            SectionHeader(title: "On this bill",
                          actionTitle: viewModel.cart.flatDiscount > 0 ? "Discount \(Money.format(viewModel.cart.flatDiscount))" : "Add discount",
                          action: { onAction(.discount) })
            ManiCard(padding: ManiSpacing.sm) {
                VStack(spacing: 0) {
                    ForEach(viewModel.cart.items) { line in
                        ManiCartLineRow(title: line.displayName,
                                        subtitle: lineSubtitle(line),
                                        totalText: Money.format(line.totalItemsPrice),
                                        quantityUnitText: line.weight == nil ? "× \(line.quantity)" : "",
                                        onTap: { onAction(.editLine(lineId: line.lineId)) },
                                        onRemove: { viewModel.removeLine(id: line.lineId) })
                    }
                }
            }
        }
    }

    private func lineSubtitle(_ line: CartItem) -> String {
        var parts = ["\(Money.format(line.finalPrice))\(line.weight != nil ? "/\(line.unit ?? "kg")" : "")"]
        if line.discountPercent > 0 { parts.append("−\(Int(line.discountPercent.rounded()))%") }
        if let name = line.doneByName { parts.append("Done by \(name)") }
        if let months = line.warrantyMonths, months > 0 { parts.append("\(months)m warranty") }
        return parts.joined(separator: " · ")
    }
}
