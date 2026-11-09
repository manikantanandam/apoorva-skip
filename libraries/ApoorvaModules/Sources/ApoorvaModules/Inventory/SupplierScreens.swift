//
//  SupplierScreens.swift
//  ApoorvaModules
//
//  Reorder (79), suppliers (80), supplier detail (81), new supplier, purchase (82).
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

// MARK: - Reorder (79)

public struct ReorderView: View {
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: ReorderViewModel
    private let onRecordPurchase: (String?, [PurchaseLine]) -> Void

    public init(viewModel: ReorderViewModel, onRecordPurchase: @escaping (String?, [PurchaseLine]) -> Void) {
        self.viewModel = viewModel
        self.onRecordPurchase = onRecordPurchase
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(viewModel.lines.count) items low\(viewModel.supplier.map { " · \($0.name)" } ?? "")")
            if viewModel.lines.isEmpty {
                ManiEmptyState(icon: .checkCircle, title: "Nothing to reorder", message: "Items show here when they drop to their low-stock mark.")
            } else {
                RowsCard {
                    ForEach(viewModel.lines) { line in
                        ManiToggleRow(title: line.item.name, subtitle: "Left \(line.item.currentStock) · order \(line.quantity)",
                                      isOn: Binding(get: { line.isSelected }, set: { _ in viewModel.toggle(line.id) }))
                        if line.isSelected {
                            Stepper("Order \(line.quantity)", value: Binding(get: { line.quantity }, set: { viewModel.setQuantity($0, for: line.id) }),
                                    in: 1...999)
                        }
                    }
                }
            }
            if !viewModel.suppliers.isEmpty {
                FlowLayout {
                    ForEach(viewModel.suppliers) { supplier in
                        ManiChip(supplier.name, isSelected: viewModel.supplierId == supplier.id) { viewModel.supplierId = supplier.id }
                    }
                }
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Send list on WhatsApp", icon: .message, isEnabled: !viewModel.selected.isEmpty) {
                    if let url = viewModel.whatsAppURL { openURL(url) }
                }
                ManiButton("Record purchase when it arrives", kind: .outline, isEnabled: !viewModel.selected.isEmpty) {
                    onRecordPurchase(viewModel.supplierId, viewModel.purchaseLines)
                }
            }
        }
        .navigationTitle("Reorder")
        .task { await viewModel.load() }
    }
}

// MARK: - Suppliers (80)

public struct SuppliersView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: SuppliersViewModel
    private let onAdd: () -> Void
    private let onSelect: (Supplier) -> Void

    public init(viewModel: SuppliersViewModel, onAdd: @escaping () -> Void, onSelect: @escaping (Supplier) -> Void) {
        self.viewModel = viewModel
        self.onAdd = onAdd
        self.onSelect = onSelect
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: viewModel.totalOwed > 0 ? "You owe \(Money.format(viewModel.totalOwed))" : "You owe nothing")
            ManiSearchField(text: $viewModel.searchText, placeholder: "Supplier name or phone")
            if viewModel.visible.isEmpty {
                ManiEmptyState(icon: .truck, title: "No suppliers yet", message: "Add who you buy from to track purchases and dues.",
                               actionTitle: "Add supplier", action: onAdd)
            } else {
                RowsCard {
                    ForEach(viewModel.visible) { supplier in
                        let owed = viewModel.owed(supplier)
                        ManiListRow(title: supplier.name, subtitle: viewModel.subtitle(supplier),
                                    value: owed > 0 ? Money.format(owed) : "—",
                                    status: owed > 0 ? ("Due", .error) : nil) { onSelect(supplier) }
                    }
                }
            }
        }
        .navigationTitle("Suppliers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) { ManiSwiftUIComponents.IconView(.plus, size: 18, color: theme.base.text) }
                    .accessibilityLabel("Add supplier")
            }
        }
        .task { await viewModel.load() }
    }
}

public struct SupplierFormView: View {
    @Bindable private var viewModel: SupplierFormViewModel
    private let onSaved: (Supplier) -> Void

    public init(viewModel: SupplierFormViewModel, onSaved: @escaping (Supplier) -> Void) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    public var body: some View {
        ScreenScroll {
            ManiInputField(label: "Name", text: $viewModel.name, placeholder: "Ramesh Traders")
            ManiInputField(label: "Phone", text: $viewModel.phone, placeholder: "98490 11223", keyboard: .phone)
            ManiInputField(label: "What they supply", text: $viewModel.what, placeholder: "Groceries")
            ManiInputField(label: "You already owe (optional)", text: $viewModel.openingDueText, placeholder: "₹", keyboard: .decimal)
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save supplier", isEnabled: viewModel.canSave) {
                Task { if let supplier = await viewModel.save() { onSaved(supplier) } }
            }
        }
        .navigationTitle("New supplier")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Supplier detail (81)

public struct SupplierDetailView: View {
    @Environment(\.maniTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: SupplierDetailViewModel
    private let onNewPurchase: () -> Void
    @State private var isPaying = false

    public init(viewModel: SupplierDetailViewModel, onNewPurchase: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onNewPurchase = onNewPurchase
    }

    public var body: some View {
        ScreenScroll {
            if let supplier = viewModel.supplier {
                ScreenSubtitle(text: "\(supplier.phone.isEmpty ? supplier.notes : supplier.phone) · since \(supplier.createdAt.formatted(.dateTime.year()))")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: ManiSpacing.sm), GridItem(.flexible())], spacing: ManiSpacing.sm) {
                    ManiKPITile(title: "You owe", value: Money.format(viewModel.owed), isHighlighted: viewModel.owed > 0)
                    ManiKPITile(title: "Bought this month", value: Money.format(viewModel.boughtThisMonth))
                }
                if let since = viewModel.owedSince { ScreenSubtitle(text: "Owed since \(since.shortDay)") }
                if supplier.openingDue > 0 {
                    ManiNote("Includes \(Money.format(supplier.openingDue)) owed before using Apoorva.", kind: .info)
                }
                if viewModel.entries.isEmpty {
                    ManiEmptyState(icon: .truck, title: "No purchases yet")
                } else {
                    RowsCard {
                        ForEach(viewModel.entries) { entry in
                            ManiListRow(title: entry.note.isEmpty ? entry.kind.rawValue.capitalized : entry.note,
                                        subtitle: entry.createdAt.shortDay + (entry.mode.map { " · \($0.uppercased())" } ?? ""),
                                        value: (entry.amount >= 0 ? "+" : "−") + Money.format(abs(entry.amount)),
                                        status: entry.amount > 0 ? ("Bought", .neutral) : ("Paid", .success))
                        }
                    }
                }
                if isPaying {
                    SectionHeader(title: "Pay supplier")
                    ManiInputField(label: "Amount", text: $viewModel.payAmountText, placeholder: Money.format(viewModel.owed), keyboard: .decimal)
                    FlowLayout {
                        ForEach([PaymentMode.cash, .upi], id: \.self) { mode in
                            ManiChip(mode.title, isSelected: viewModel.payMode == mode) { viewModel.payMode = mode }
                        }
                    }
                }
                if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
            } else {
                ProgressView()
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                if isPaying {
                    ManiButton("Record payment", isEnabled: (Double(viewModel.payAmountText) ?? 0) > 0) {
                        Task { if await viewModel.pay() { isPaying = false } }
                    }
                } else {
                    ManiButton("Pay supplier", icon: .cashOut) {
                        if viewModel.payAmountText.isEmpty, viewModel.owed > 0 { viewModel.payAmountText = String(Int(viewModel.owed)) }
                        isPaying = true
                    }
                }
                ManiButton("New purchase", kind: .outline, action: onNewPurchase)
            }
        }
        .navigationTitle(viewModel.supplier?.name ?? "Supplier")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = viewModel.whatsAppURL, viewModel.supplier?.phone.isEmpty == false {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { openURL(url) } label: { ManiSwiftUIComponents.IconView(.message, size: 18, color: theme.base.text) }
                }
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Purchase (82)

public struct PurchaseFormView: View {
    @Bindable private var viewModel: PurchaseFormViewModel
    private let onSaved: (Purchase) -> Void
    private let onAddSupplier: () -> Void

    public init(viewModel: PurchaseFormViewModel, onSaved: @escaping (Purchase) -> Void, onAddSupplier: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSaved = onSaved
        self.onAddSupplier = onAddSupplier
    }

    public var body: some View {
        ScreenScroll {
            if viewModel.suppliers.isEmpty {
                ManiEmptyState(icon: .truck, title: "Add a supplier first", actionTitle: "Add supplier", action: onAddSupplier)
            } else {
                FlowLayout {
                    ForEach(viewModel.suppliers) { supplier in
                        ManiChip(supplier.name, isSelected: viewModel.supplierId == supplier.id) { viewModel.supplierId = supplier.id }
                    }
                }
                ManiSegmentedControl(selection: $viewModel.kind, options: PurchaseFormViewModel.Kind.allCases.map { ($0, $0.rawValue) })
                ManiSegmentedControl(selection: $viewModel.entry, options: PurchaseFormViewModel.Entry.allCases.map { ($0, $0.rawValue) })
                if viewModel.entry == .items {
                    ManiSearchField(text: $viewModel.itemSearch, placeholder: "Add an item")
                    if !viewModel.itemMatches.isEmpty {
                        RowsCard {
                            ForEach(viewModel.itemMatches) { item in
                                ManiListRow(title: item.name, subtitle: "Stock \(item.currentStock)", value: "Add") { viewModel.add(item) }
                            }
                        }
                    }
                    ForEach(viewModel.lines) { line in
                        ManiCard {
                            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                                HStack {
                                    Text(line.itemName).font(.body.weight(.medium))
                                    Spacer()
                                    Text(Money.format(line.total))
                                    Button { viewModel.remove(line.itemId) } label: { ManiSwiftUIComponents.IconView(.trash, size: 14) }
                                        .buttonStyle(.plain)
                                }
                                HStack {
                                    Stepper("Qty \(Int(line.quantity))", value: Binding(get: { line.quantity },
                                                                                         set: { viewModel.update(line.itemId, quantity: $0) }),
                                            in: 0...9999)
                                }
                                ManiInputField(label: "Cost each", text: Binding(get: { line.unitCost == 0 ? "" : String(format: "%g", line.unitCost) },
                                                                                 set: { viewModel.update(line.itemId, unitCost: Double($0) ?? 0) }),
                                               placeholder: "₹", keyboard: .decimal)
                            }
                        }
                    }
                } else {
                    ManiInputField(label: "Bill total", text: $viewModel.totalText, placeholder: "₹", keyboard: .decimal)
                }
                ManiInputField(label: "Note (bill number, etc.)", text: $viewModel.note)
                ManiSegmentedControl(selection: $viewModel.payment, options: PurchaseFormViewModel.Payment.allCases.map { ($0, $0.rawValue) })
                if viewModel.payment == .partPaid {
                    ManiInputField(label: "Paid now", text: $viewModel.paidText, placeholder: "₹", keyboard: .decimal)
                }
                if viewModel.payment != .credit {
                    FlowLayout {
                        ForEach([PaymentMode.cash, .upi], id: \.self) { mode in
                            ManiChip(mode.title, isSelected: viewModel.paidMode == mode) { viewModel.paidMode = mode }
                        }
                    }
                }
                if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
            }
        } bottom: {
            if !viewModel.suppliers.isEmpty {
                ManiButton(viewModel.saveTitle, isLoading: viewModel.isSaving, isEnabled: viewModel.canSave) {
                    Task { if let purchase = await viewModel.save() { onSaved(purchase) } }
                }
            }
        }
        .navigationTitle(viewModel.kind == .purchase ? "New purchase" : "Return to supplier")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
