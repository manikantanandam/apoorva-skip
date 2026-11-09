//
//  SellScreens.swift
//  ApoorvaModules
//
//  Orders (58), new order (59), order detail (60), warranty (63).
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

private extension OrderStatus {
    var kind: ManiStatusKind {
        switch self {
        case .open: .warning
        case .ready: .success
        case .delivered: .neutral
        case .cancelled: .error
        }
    }
}

// MARK: - Orders (58)

public struct OrdersListView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: OrdersViewModel
    private let onAdd: () -> Void
    private let onSelect: (Order) -> Void

    public init(viewModel: OrdersViewModel, onAdd: @escaping () -> Void, onSelect: @escaping (Order) -> Void) {
        self.viewModel = viewModel
        self.onAdd = onAdd
        self.onSelect = onSelect
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: viewModel.subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ManiSpacing.sm) {
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        ManiChip(status.title, isSelected: viewModel.status == status) { viewModel.status = status }
                    }
                }
            }
            if viewModel.visible.isEmpty {
                ManiEmptyState(icon: .order, title: "No \(viewModel.status.title.lowercased()) orders",
                               message: "Take advances for custom work, repairs or home delivery.",
                               actionTitle: viewModel.status == .open ? "New order" : nil,
                               action: viewModel.status == .open ? onAdd : nil)
            } else {
                RowsCard {
                    ForEach(viewModel.visible) { order in
                        ManiListRow(title: order.customerName,
                                    subtitle: "\(order.details) · \(order.status == .delivered ? "delivered" : "due") \(order.readyBy.shortDay)\(order.isOverdue ? " · late" : "")",
                                    value: order.advance > 0 ? "\(Money.format(order.advance)) adv" : Money.format(0),
                                    status: (order.status.title, order.isOverdue ? .error : order.status.kind)) { onSelect(order) }
                    }
                }
            }
        }
        .navigationTitle("Orders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) { ManiSwiftUIComponents.IconView(.plus, size: 18, color: theme.base.text) }
                    .accessibilityLabel("New order")
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - New order (59)

public struct OrderFormView: View {
    @Bindable private var viewModel: OrderFormViewModel
    private let onSaved: (Order) -> Void

    public init(viewModel: OrderFormViewModel, onSaved: @escaping (Order) -> Void) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    public var body: some View {
        ScreenScroll {
            ManiInputField(label: "Customer phone", text: $viewModel.customerPhone, placeholder: "98480 44556", keyboard: .phone)
            ManiInputField(label: "Customer name", text: $viewModel.customerName, placeholder: "Lavanya K")
            if !viewModel.matches.isEmpty {
                RowsCard {
                    ForEach(viewModel.matches) { customer in
                        ManiListRow(title: customer.name, subtitle: customer.phone, value: "Use") { viewModel.pick(customer) }
                    }
                }
            }
            ManiInputField(label: "What", text: $viewModel.details, placeholder: "Custom haram like NK-118, longer chain")
            ManiInputField(label: "Total price", text: $viewModel.totalText, placeholder: "₹", keyboard: .decimal)
            ManiInputField(label: "Advance received", text: $viewModel.advanceText, placeholder: "₹", keyboard: .decimal)
            FlowLayout {
                ForEach([PaymentMode.cash, .upi], id: \.self) { mode in
                    ManiChip(mode.title, isSelected: viewModel.advanceMode == mode) { viewModel.advanceMode = mode }
                }
            }
            SectionHeader(title: "Ready by")
            FlowLayout {
                ForEach(OrderFormViewModel.ReadyBy.allCases, id: \.self) { choice in
                    ManiChip(choice == .pick && viewModel.readyByChoice == .pick ? viewModel.pickedDate.shortDay : choice.rawValue,
                             isSelected: viewModel.readyByChoice == choice) { viewModel.readyByChoice = choice }
                }
            }
            if viewModel.readyByChoice == .pick {
                DatePicker("Ready by", selection: $viewModel.pickedDate, in: Date()..., displayedComponents: .date)
            }
            ManiSegmentedControl(selection: $viewModel.fulfilment, options: OrderFulfilment.allCases.map { ($0, $0.title) })
            ManiToggleRow(title: "WhatsApp when ready", subtitle: "Customer gets a message", isOn: $viewModel.notifyWhenReady)
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save order · balance \(Money.format(viewModel.balance))", isLoading: viewModel.isSaving, isEnabled: viewModel.canSave) {
                Task { if let order = await viewModel.save() { onSaved(order) } }
            }
        }
        .navigationTitle("New order")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.customerPhone) { _, _ in viewModel.updateMatches() }
        .onChange(of: viewModel.customerName) { _, _ in viewModel.updateMatches() }
        .task { await viewModel.load() }
    }
}

// MARK: - Order detail (60)

public struct OrderDetailView: View {
    @Environment(\.maniTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: OrderDetailViewModel
    private let onDeliver: (PosCart) -> Void

    public init(viewModel: OrderDetailViewModel, onDeliver: @escaping (PosCart) -> Void) {
        self.viewModel = viewModel
        self.onDeliver = onDeliver
    }

    public var body: some View {
        ScreenScroll {
            if let order = viewModel.order {
                ScreenSubtitle(text: "\(order.customerName) · \(order.details)")
                ManiKeyValueSummary(rows: [
                    ManiKeyValue("Total", Money.format(order.total)),
                    ManiKeyValue("Advance (\(order.advanceMode.uppercased()), \(order.createdAt.shortDay))", "−" + Money.format(order.advance)),
                    ManiKeyValue("Balance", Money.format(order.balance))
                ])
                RowsCard {
                    ManiListRow(title: "Ordered", subtitle: "\(order.createdAt.shortDay)\(order.createdByName.isEmpty ? "" : " · by \(order.createdByName)")",
                                status: ("Done", .success))
                    ManiListRow(title: "Ready", subtitle: order.readyAt.map { $0.shortDay } ?? "Due \(order.readyBy.shortDay)",
                                status: order.readyAt != nil ? ("Done", .success) : ("Open", .warning))
                    ManiListRow(title: order.fulfilment == .delivery ? "Delivered" : "Picked up",
                                subtitle: order.deliveredAt.map { $0.shortDay } ?? "Waiting",
                                status: order.status == .delivered ? ("Done", .success) : (order.status == .cancelled ? ("Cancelled", .error) : ("Open", .warning)))
                }
                if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
            } else {
                ProgressView()
            }
        } bottom: {
            if let order = viewModel.order, order.status == .open || order.status == .ready {
                VStack(spacing: ManiSpacing.sm) {
                    ManiButton(order.balance > 0 ? "Deliver & collect \(Money.format(order.balance))" : "Deliver") {
                        if let cart = viewModel.deliveryCart() { onDeliver(cart) }
                    }
                    ManiButton("Send ready message", icon: .message, kind: .outline) {
                        Task {
                            if order.status == .open { await viewModel.markReady() }
                            if let url = viewModel.readyMessageURL { openURL(url) }
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.order.map { "Order #\($0.number)" } ?? "Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let order = viewModel.order, order.status == .open || order.status == .ready {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if order.status == .open { Button("Mark ready") { Task { await viewModel.markReady() } } }
                        Button("Cancel order", role: .destructive) { Task { await viewModel.cancel() } }
                    } label: {
                        ManiSwiftUIComponents.IconView(.more, size: 18, color: theme.base.text)
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Warranty (63)

public struct WarrantyView: View {
    @Bindable private var viewModel: WarrantyViewModel

    public init(viewModel: WarrantyViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Check before replacing")
            ManiSearchField(text: $viewModel.query, placeholder: "Phone or bill number")
            if viewModel.lines.isEmpty {
                ManiEmptyState(icon: .warranty, title: viewModel.query.isEmpty ? "No warranties yet" : "Nothing found",
                               message: "Lines sold with a warranty show up here.")
            } else {
                RowsCard {
                    ForEach(viewModel.lines) { line in
                        ManiListRow(title: line.item.categoryName,
                                    subtitle: "Bill #\(line.sale.displayNumber) · sold \(line.sale.timestamp.shortDay) · till \(line.until.shortDay)",
                                    value: line.months % 12 == 0 ? "\(line.months / 12) year\(line.months == 12 ? "" : "s")" : "\(line.months) months",
                                    status: line.isActive ? ("Active", .success) : ("Expired", .error)) { viewModel.selected = line }
                    }
                }
            }
            if let line = viewModel.selected {
                SectionHeader(title: "\(line.item.categoryName) · claim")
                ForEach(viewModel.claims(for: line)) { claim in
                    ManiNote("\(claim.action.title) on \(claim.createdAt.shortDay): \(claim.note)", kind: .info)
                }
                if line.isActive {
                    FlowLayout {
                        ForEach(WarrantyAction.allCases, id: \.self) { action in
                            ManiChip(action.title, isSelected: viewModel.action == action) { viewModel.action = action }
                        }
                    }
                    ManiInputField(label: "Note", text: $viewModel.note, placeholder: "Strap broken · replaced with same model")
                } else {
                    ManiNote("This warranty ended on \(line.until.shortDay).", kind: .warning)
                }
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            if viewModel.selected?.isActive == true {
                ManiButton("Record claim", isEnabled: viewModel.canClaim) {
                    Task { _ = await viewModel.recordClaim() }
                }
            }
        }
        .navigationTitle("Warranty")
        .onChange(of: viewModel.query) { _, _ in viewModel.search() }
        .task { await viewModel.load() }
    }
}
