//
//  BillsScreens.swift
//  ApoorvaModules
//
//  Designs 54 (list), 57 (filters), 55 (detail), 56 (cancel), 50 (edit).
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels

// MARK: - 54 Bills list

public struct BillsListView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: BillsViewModel
    private let onSelect: (Sale) -> Void
    private let onFilters: () -> Void

    public init(viewModel: BillsViewModel, onSelect: @escaping (Sale) -> Void, onFilters: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSelect = onSelect
        self.onFilters = onFilters
    }

    public var body: some View {
        ScreenScroll(spacing: ManiSpacing.md) {
            ManiAppBar(title: "Bills") {
                EmptyView()
            } trailing: {
                Button(action: onFilters) {
                    ManiSwiftUIComponents.IconView(.filter, size: 18, color: viewModel.quick == nil ? theme.accent.accent : theme.base.text)
                }
            }
            ScreenSubtitle(text: "\(Money.format(viewModel.todayTotal)) today · \(viewModel.todayCount) bills")
            ManiSearchField(text: $viewModel.searchText, placeholder: "Search name, phone or bill #")
            ManiChipGroup(items: BillQuickFilter.allCases, label: \.rawValue, selection: $viewModel.quick)

            if viewModel.sales.isEmpty {
                ManiEmptyState(icon: .receipt, title: "No bills here", message: "Bills you create show up here.")
            } else {
                RowsCard {
                    ForEach(Array(viewModel.sales.enumerated()), id: \.element.id) { index, sale in
                        if index > 0 { Divider() }
                        ManiListRow(
                            avatar: ManiAvatar(initials: String((sale.customerName.isEmpty ? "W" : sale.customerName).prefix(1))),
                            title: sale.customerName.isEmpty ? "Walk-in" : sale.customerName,
                            subtitle: "\(sale.displayNumber) · \(sale.timestamp.timeOnly) · \(sale.primaryMode)",
                            value: Money.format(sale.netPayable),
                            status: status(for: sale),
                            action: { onSelect(sale) }
                        )
                    }
                }
            }
        }
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.load() }
    }

    private func status(for sale: Sale) -> (text: String, kind: ManiStatusKind) {
        if sale.isCancelled { return ("Cancelled", .error) }
        if sale.isReturn { return ("Return", .neutral) }
        if sale.isDue { return ("Due", .warning) }
        return ("Paid", .success)
    }
}

// MARK: - 57 Filters

public struct BillFiltersView: View {
    private let viewModel: BillsViewModel
    @State private var draft: BillFilters
    private let onClose: () -> Void

    public init(viewModel: BillsViewModel, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self._draft = State(initialValue: viewModel.filters)
        self.onClose = onClose
    }

    public var body: some View {
        ScreenScroll {
            SectionHeader(title: "Date")
            FlowLayout {
                ForEach(BillDateRange.allCases, id: \.self) { range in
                    ManiChip(range.rawValue, isSelected: draft.range == range) { draft.range = range }
                }
            }
            SectionHeader(title: "Payment")
            FlowLayout {
                ForEach(PaymentMode.allCases, id: \.self) { mode in
                    ManiChip(mode == .upi ? "UPI" : mode.rawValue.capitalized, isSelected: draft.modes.contains(mode)) {
                        if draft.modes.contains(mode) { draft.modes.remove(mode) } else { draft.modes.insert(mode) }
                    }
                }
            }
            SectionHeader(title: "Status")
            ManiSegmentedControl(selection: $draft.status, options: BillStatusFilter.allCases.map { (value: $0, title: $0.rawValue) })
            if !viewModel.staffOptions.isEmpty {
                SectionHeader(title: "Staff")
                FlowLayout {
                    ForEach(viewModel.staffOptions, id: \.id) { staff in
                        ManiChip(staff.name, isSelected: draft.staffIds.contains(staff.id)) {
                            if draft.staffIds.contains(staff.id) { draft.staffIds.remove(staff.id) } else { draft.staffIds.insert(staff.id) }
                        }
                    }
                }
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Show \(viewModel.count(with: draft)) bills") {
                    viewModel.applyFilters(draft)
                    onClose()
                }
                ManiButton("Reset", kind: .outline) {
                    viewModel.quick = .today
                    onClose()
                }
            }
        }
        .navigationTitle("Filters")
    }
}

// MARK: - 55 Bill detail

public struct BillDetailView: View {
    @Environment(\.maniTheme) private var theme
    private let session: AppSession
    @Bindable private var viewModel: BillDetailViewModel
    private let onReprint: (Sale) -> Void
    private let onCancel: (Sale) -> Void
    private let onEdit: (Sale) -> Void
    private let onReturn: (Sale) -> Void
    private let onCollect: (Sale) -> Void
    private let onLocked: (String) -> Void

    public init(session: AppSession, viewModel: BillDetailViewModel,
                onReprint: @escaping (Sale) -> Void, onCancel: @escaping (Sale) -> Void,
                onEdit: @escaping (Sale) -> Void, onReturn: @escaping (Sale) -> Void,
                onCollect: @escaping (Sale) -> Void, onLocked: @escaping (String) -> Void) {
        self.session = session
        self.viewModel = viewModel
        self.onReprint = onReprint
        self.onCancel = onCancel
        self.onEdit = onEdit
        self.onReturn = onReturn
        self.onCollect = onCollect
        self.onLocked = onLocked
    }

    public var body: some View {
        Group {
            if let sale = viewModel.sale {
                content(for: sale)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(viewModel.sale?.displayNumber ?? "Bill")
        .toolbar {
            if let sale = viewModel.sale, !sale.isCancelled {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Edit bill") { guarded(.editSavedBill) { onEdit(sale) } }
                        if session.isOn(.returns) && !sale.isReturn {
                            Button("Return / exchange") { guarded(.returns) { onReturn(sale) } }
                        }
                        Button("Cancel bill", role: .destructive) { guarded(.cancelBill) { onCancel(sale) } }
                    } label: {
                        ManiSwiftUIComponents.IconView(.more, size: 18, color: theme.base.text)
                    }
                }
            }
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder private func content(for sale: Sale) -> some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(sale.customerName.isEmpty ? "Walk-in" : sale.customerName) · \(sale.timestamp.formatted(date: .abbreviated, time: .shortened))\(viewModel.staffName.map { " · by \($0)" } ?? "")")
            if sale.isCancelled {
                ManiNote("Cancelled\(sale.cancelReason.map { ": \($0)" } ?? ""). Stock and dues were reversed.", kind: .error)
            }
            if let reason = sale.editReason {
                ManiNote("Edited: \(reason)", kind: .info)
            }
            RowsCard {
                ForEach(Array(sale.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider() }
                    ManiListRow(title: item.categoryName, subtitle: "\(item.qty) × \(Money.format(item.finalPrice))",
                                value: Money.format(item.totalAmount))
                }
            }
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Subtotal", Money.format(sale.subTotal)),
                ManiKeyValue("Discount", "-" + Money.format(sale.overallDiscountAmount)),
                ManiKeyValue("Paid", Money.format(viewModel.paid)),
                ManiKeyValue("Balance", Money.format(sale.dueAmount))
            ])
            FlowLayout {
                ManiChip("Reprint", icon: .printer) { onReprint(sale) }
                ShareLink(item: viewModel.shareText) {
                    Text("Share").padding(.horizontal, ManiSpacing.md).frame(minHeight: 32)
                }
                if !sale.isCancelled {
                    ManiChip("Cancel bill", icon: .close) { guarded(.cancelBill) { onCancel(sale) } }
                }
            }
        } bottom: {
            if sale.isDue {
                ManiButton("Collect \(Money.format(sale.dueAmount))") { onCollect(sale) }
            }
        }
    }

    private func guarded(_ permission: Permission, _ action: () -> Void) {
        switch session.access(permission) {
        case .allowed: action()
        case .locked(let reason): onLocked(reason)
        }
    }
}

// MARK: - 56 Cancel bill

public struct CancelBillView: View {
    @Bindable private var viewModel: CancelBillViewModel
    private let onCancelled: () -> Void

    public init(viewModel: CancelBillViewModel, onCancelled: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onCancelled = onCancelled
    }

    public var body: some View {
        ScreenScroll {
            SectionHeader(title: "Why are you cancelling?")
            ManiPickList(options: CancelBillViewModel.reasons.map { ManiPickOption(value: $0, title: $0) }, selection: $viewModel.reason)
            ManiInputField(label: "Note (optional)", text: $viewModel.note)
            ManiNote("Stock goes back and any due is reversed. The bill stays in the audit log as Cancelled.", kind: .warning)
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Cancel bill", isLoading: viewModel.isWorking) {
                Task { if await viewModel.cancel() { onCancelled() } }
            }
        }
        .navigationTitle("Cancel bill")
    }
}

// MARK: - 50 Edit bill

public struct BillEditView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: BillEditViewModel
    private let onSaved: () -> Void

    public init(viewModel: BillEditViewModel, onSaved: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSaved = onSaved
    }

    public var body: some View {
        ScreenScroll {
            RowsCard {
                ForEach(Array(viewModel.lines.enumerated()), id: \.element.id) { index, line in
                    if index > 0 { Divider() }
                    HStack(spacing: ManiSpacing.md) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(line.item.categoryName)
                                .font(theme.typography.body.weight(.medium))
                                .strikethrough(line.isRemoved)
                            Text(Money.format(line.item.finalPrice) + " each")
                                .font(theme.typography.secondary)
                                .foregroundStyle(theme.base.textSecondary)
                        }
                        Spacer()
                        if line.isRemoved {
                            ManiStatusBadge("Removed", kind: .error)
                        }
                        Button { viewModel.setQty(line.qty - 1, for: line.id) } label: {
                            ManiSwiftUIComponents.IconView(.minus, size: 14, color: theme.accent.accent)
                        }
                        Text("\(line.qty)").font(theme.typography.body.weight(.semibold).monospacedDigit()).frame(minWidth: 24)
                        Button { viewModel.setQty(line.qty + 1, for: line.id) } label: {
                            ManiSwiftUIComponents.IconView(.plus, size: 14, color: theme.accent.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, ManiSpacing.sm)
                }
            }
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Old total", Money.format(viewModel.original?.netPayable ?? 0)),
                ManiKeyValue("New total", Money.format(viewModel.newTotal))
            ])
            ManiInputField(label: "Reason for edit", text: $viewModel.reason, placeholder: "e.g. Customer returned one item")
            ManiNote("Edits are saved in the audit log with your name and the reason.")
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save changes", isLoading: viewModel.isWorking, isEnabled: viewModel.canSave) {
                Task { if await viewModel.save() { onSaved() } }
            }
        }
        .navigationTitle("Edit bill \(viewModel.original?.displayNumber ?? "")")
        .task { await viewModel.load() }
    }
}
