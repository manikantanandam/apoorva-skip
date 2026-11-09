//
//  MoneyScreens.swift
//  ApoorvaModules
//
//  Cashflow day (83), cash entry (84), close day (85), history (86), expenses (87, 88),
//  today's summary (89).
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

// MARK: - Day (83)

public struct CashDayView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CashDayViewModel
    private let canClose: Bool
    private let onAdd: () -> Void
    private let onClose: () -> Void
    private let onHistory: () -> Void

    public init(viewModel: CashDayViewModel, canClose: Bool, onAdd: @escaping () -> Void, onClose: @escaping () -> Void,
                onHistory: @escaping () -> Void) {
        self.viewModel = viewModel
        self.canClose = canClose
        self.onAdd = onAdd
        self.onClose = onClose
        self.onHistory = onHistory
    }

    private var subtitle: String {
        let day = viewModel.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        if let close = viewModel.close { return "\(day) · closed by \(close.closedByName)" }
        return viewModel.isToday ? "\(day) · open" : day
    }

    public var body: some View {
        ScreenScroll {
            HStack {
                Button { Task { await viewModel.step(-1) } } label: { ManiSwiftUIComponents.IconView(.chevronRight, size: 14).rotationEffect(.degrees(180)) }
                ScreenSubtitle(text: subtitle).frame(maxWidth: .infinity)
                Button { Task { await viewModel.step(1) } } label: { ManiSwiftUIComponents.IconView(.chevronRight, size: 14) }
                    .disabled(viewModel.isToday)
            }
            .buttonStyle(.plain)
            if let day = viewModel.day {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: ManiSpacing.sm), GridItem(.flexible())], spacing: ManiSpacing.sm) {
                    ManiKPITile(title: viewModel.isClosed ? "Counted" : "Expected closing",
                                value: Money.format(viewModel.close?.countedCash ?? day.expectedClosing), isHighlighted: true)
                    ManiKPITile(title: "Opening", value: Money.format(day.opening))
                    ManiKPITile(title: "Cash in", value: Money.format(day.cashIn))
                    ManiKPITile(title: "Cash out", value: Money.format(day.cashOut))
                }
                let modes = [PaymentMode.cash, .upi, .card].compactMap { mode in
                    (day.byMode[mode] ?? 0) > 0 ? ManiSplitSegment(mode.title, day.byMode[mode] ?? 0) : nil
                }
                if !modes.isEmpty { ManiSplitBarCard(title: "Sales by mode", segments: modes) }
                SectionHeader(title: "Entries", actionTitle: "History", action: onHistory)
                RowsCard {
                    if day.cashSales != 0 {
                        ManiListRow(title: "Bill sales (cash)", subtitle: "In · auto", value: "+" + Money.format(day.cashSales))
                    }
                    ForEach(day.entries, id: \.id) { entry in
                        ManiListRow(title: entry.particulars,
                                    subtitle: "\(entry.transactionType == .credit ? "In" : "Out") · \(entry.timestamp.timeOnly) · \(entry.paymentMode == .cash ? "Cash" : "Bank")",
                                    value: (entry.transactionType == .credit ? "+" : "−") + Money.format(entry.amount))
                    }
                    if day.cashSales == 0 && day.entries.isEmpty {
                        ManiListRow(title: "No entries yet", subtitle: "Bills and cash in/out show here")
                    }
                }
            } else {
                ProgressView()
            }
        } bottom: {
            if viewModel.isToday && !viewModel.isClosed && canClose {
                ManiButton("Close day", icon: .lock, action: onClose)
            }
        }
        .navigationTitle("Cashflow")
        .toolbar {
            if !viewModel.isClosed {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAdd) { ManiSwiftUIComponents.IconView(.plus, size: 18, color: theme.base.text) }
                        .accessibilityLabel("Add cash entry")
                }
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Cash entry (84)

public struct CashEntryView: View {
    @Bindable private var viewModel: CashEntryViewModel
    private let onDone: () -> Void

    public init(viewModel: CashEntryViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            ManiSegmentedControl(selection: $viewModel.isIn, options: [(true, "Cash in"), (false, "Cash out")])
            ManiHeroAmount("₹" + (viewModel.amountText.isEmpty ? "0" : viewModel.amountText), caption: viewModel.particulars)
            if !viewModel.isIn {
                FlowLayout {
                    ForEach(CashEntryViewModel.Purpose.allCases, id: \.self) { purpose in
                        ManiChip(purpose.rawValue, isSelected: viewModel.purpose == purpose) { viewModel.purpose = purpose }
                    }
                }
            }
            ManiInputField(label: "Note (optional)", text: $viewModel.note, placeholder: viewModel.isIn ? "Owner added float" : "Ramesh Traders")
            ManiKeypad { key in viewModel.amountText = key.apply(to: viewModel.amountText) }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save entry", isEnabled: viewModel.amount > 0) {
                Task { if await viewModel.save() { onDone() } }
            }
        }
        .navigationTitle("Cash entry")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Close day (85)

public struct DayCloseView: View {
    @Bindable private var viewModel: DayCloseViewModel
    private let onDone: () -> Void

    public init(viewModel: DayCloseViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: viewModel.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Expected cash", Money.format(viewModel.expected)),
                ManiKeyValue("Counted cash", Money.format(viewModel.counted)),
                ManiKeyValue("Difference", (viewModel.difference > 0 ? "+" : "") + Money.format(viewModel.difference))
            ])
            ManiInputField(label: "Counted cash", text: $viewModel.countedText, placeholder: "₹", keyboard: .decimal)
            ManiInputField(label: "Note", text: $viewModel.note, placeholder: "₹50 given as change float")
            ManiToggleRow(title: "Carry forward as opening",
                          subtitle: "\(Money.format(viewModel.counted)) for \(viewModel.tomorrow.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))",
                          isOn: $viewModel.carryForward)
            ManiNote("Closing locks today's entries. Owners can reopen from Cash history.", kind: .info)
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Close day", icon: .lock, isLoading: viewModel.isSaving, isEnabled: !viewModel.countedText.isEmpty) {
                Task { if await viewModel.close() { onDone() } }
            }
        }
        .navigationTitle("Close day")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - History (86)

public struct CashHistoryView: View {
    @Bindable private var viewModel: CashHistoryViewModel
    private let canReopen: Bool
    private let onSelect: (Date) -> Void

    public init(viewModel: CashHistoryViewModel, canReopen: Bool, onSelect: @escaping (Date) -> Void) {
        self.viewModel = viewModel
        self.canReopen = canReopen
        self.onSelect = onSelect
    }

    public var body: some View {
        ScreenScroll {
            HStack {
                Button { Task { await viewModel.step(-1) } } label: { Text("‹ Previous") }
                Spacer()
                ScreenSubtitle(text: viewModel.title)
                Spacer()
                Button { Task { await viewModel.step(1) } } label: { Text("Next ›") }
            }
            .buttonStyle(.plain)
            RowsCard {
                ForEach(viewModel.rows) { row in
                    let day = row.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    if let close = row.close {
                        ManiListRow(title: day,
                                    subtitle: "Closed by \(close.closedByName) · diff \(Money.format(close.difference))",
                                    value: Money.format(close.countedCash),
                                    status: abs(close.difference) < 1 ? ("Matched", .success) : (close.difference < 0 ? ("Short", .warning) : ("Over", .warning))) {
                            onSelect(row.date)
                        }
                        .contextMenu {
                            if canReopen { Button("Reopen day") { Task { await viewModel.reopen(row) } } }
                        }
                    } else {
                        ManiListRow(title: day, subtitle: row.hadSales ? "Not closed" : "Shop closed", value: "—") { onSelect(row.date) }
                    }
                }
            }
            if canReopen { ScreenSubtitle(text: "Long-press a closed day to reopen it.") }
        }
        .navigationTitle("Cash history")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: viewModel.csv) { ManiSwiftUIComponents.IconView(.download, size: 18) }
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Expenses (87, 88)

public struct ExpensesView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: ExpensesViewModel
    private let onAdd: () -> Void
    private let onSelect: (Expense) -> Void

    public init(viewModel: ExpensesViewModel, onAdd: @escaping () -> Void, onSelect: @escaping (Expense) -> Void) {
        self.viewModel = viewModel
        self.onAdd = onAdd
        self.onSelect = onSelect
    }

    public var body: some View {
        ScreenScroll {
            HStack {
                Button { Task { await viewModel.step(-1) } } label: { Text("‹") }
                ScreenSubtitle(text: viewModel.title).frame(maxWidth: .infinity)
                Button { Task { await viewModel.step(1) } } label: { Text("›") }
            }
            .buttonStyle(.plain)
            if viewModel.expenses.isEmpty {
                ManiEmptyState(icon: .wallet, title: "No expenses this month", actionTitle: "Add expense", action: onAdd)
            } else {
                ManiSplitBarCard(title: "Where money went", segments: viewModel.byCategory.prefix(4).map { ManiSplitSegment($0.category.title, $0.amount) })
                RowsCard {
                    ForEach(viewModel.expenses) { expense in
                        ManiListRow(title: expense.title,
                                    subtitle: "\(expense.date.shortDay)\(expense.repeatsMonthly ? " · repeats monthly" : "") · \(expense.category.title)",
                                    value: Money.format(expense.amount)) { onSelect(expense) }
                    }
                }
            }
        }
        .navigationTitle("Expenses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAdd) { ManiSwiftUIComponents.IconView(.plus, size: 18, color: theme.base.text) }
                    .accessibilityLabel("Add expense")
            }
        }
        .task { await viewModel.load() }
    }
}

public struct ExpenseFormView: View {
    @Bindable private var viewModel: ExpenseFormViewModel
    private let onDone: () -> Void

    public init(viewModel: ExpenseFormViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            ManiHeroAmount("₹" + (viewModel.amountText.isEmpty ? "0" : viewModel.amountText), caption: viewModel.displayTitle)
            FlowLayout {
                ForEach(ExpenseCategory.allCases.filter { $0 != .supplier && $0 != .tea }, id: \.self) { category in
                    ManiChip(category.title, isSelected: viewModel.category == category) { viewModel.category = category }
                }
            }
            ManiInputField(label: "Name (optional)", text: $viewModel.title, placeholder: "\(viewModel.category.title) bill")
            ManiSegmentedControl(selection: $viewModel.mode, options: [("cash", "Cash"), ("upi", "UPI"), ("bank", "Bank")])
            DatePicker("Date", selection: $viewModel.date, in: ...Date(), displayedComponents: .date)
            ManiToggleRow(title: "Repeats every month", subtitle: "Shown as monthly in the list", isOn: $viewModel.repeatsMonthly)
            ManiKeypad { key in viewModel.amountText = key.apply(to: viewModel.amountText) }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save expense", isEnabled: viewModel.canSave) {
                Task { if await viewModel.save() { onDone() } }
            }
        }
        .navigationTitle(viewModel.expenseId == nil ? "New expense" : "Edit expense")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - Today's summary (89)

public struct DailySummaryView: View {
    @Bindable private var viewModel: DailySummaryViewModel

    public init(viewModel: DailySummaryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(viewModel.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))\(viewModel.isClosed ? " · day closed" : "")")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: ManiSpacing.sm), GridItem(.flexible())], spacing: ManiSpacing.sm) {
                ManiKPITile(title: "Sales · \(viewModel.bills) bills", value: Money.format(viewModel.sales), isHighlighted: true)
                ManiKPITile(title: "Profit (est.)", value: Money.format(viewModel.profit))
                ManiKPITile(title: "Cash", value: Money.format(viewModel.byMode[.cash] ?? 0))
                ManiKPITile(title: "UPI", value: Money.format(viewModel.byMode[.upi] ?? 0))
            }
            ManiKeyValueSummary(rows: [
                ManiKeyValue("Dues collected", Money.format(viewModel.duesCollected)),
                ManiKeyValue("New credit given", Money.format(viewModel.newCredit)),
                ManiKeyValue("Expenses", Money.format(viewModel.expenses)),
                ManiKeyValue("Top item", viewModel.topItem ?? "—")
            ], emphasizeLast: false)
        } bottom: {
            ShareLink(item: viewModel.shareText) {
                Text("Share on WhatsApp").frame(maxWidth: .infinity, minHeight: ManiTouchTarget.minimum)
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Today's summary")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
