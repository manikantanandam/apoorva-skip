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
    /// Opens an entry for editing. Entries of a closed day are read-only, so reopen the day first.
    private let onEdit: ((CashflowTransaction) -> Void)?
    @State private var showsCalendar = false

    public init(viewModel: CashDayViewModel, canClose: Bool, onAdd: @escaping () -> Void, onClose: @escaping () -> Void,
                onHistory: @escaping () -> Void, onEdit: ((CashflowTransaction) -> Void)? = nil) {
        self.viewModel = viewModel
        self.canClose = canClose
        self.onAdd = onAdd
        self.onClose = onClose
        self.onHistory = onHistory
        self.onEdit = onEdit
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
                Button { showsCalendar = true } label: {
                    HStack(spacing: ManiSpacing.xs) {
                        ScreenSubtitle(text: subtitle)
                        Image(systemName: "calendar")
                            .font(.footnote)
                            .foregroundStyle(theme.base.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Pick a date")
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
                if onEdit != nil && !viewModel.isClosed && !day.entries.isEmpty {
                    ScreenSubtitle(text: "Tap an entry to edit or delete it.")
                }
                RowsCard {
                    if day.cashSales != 0 {
                        ManiListRow(title: "Bill sales (cash)", subtitle: "In · auto", value: "+" + Money.format(day.cashSales))
                    }
                    ForEach(day.entries, id: \.id) { entry in
                        ManiListRow(title: entry.particulars,
                                    subtitle: entry.rowSubtitle,
                                    // A transfer is neither in nor out of the shop, so it carries no sign.
                                    value: (entry.isTransfer ? "" : (entry.transactionType == .credit ? "+" : "−")) + Money.format(entry.amount),
                                    action: viewModel.isClosed ? nil : onEdit.map { edit in { edit(entry) } })
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
        .sheet(isPresented: $showsCalendar) {
            ScreenScroll {
                ManiAppBar(title: "Pick a date")
                CashCalendarView(selected: viewModel.date, closedDayKeys: viewModel.closedDayKeys) { picked in
                    showsCalendar = false
                    Task { await viewModel.go(to: picked) }
                }
            }
        }
    }
}

/// How category, sub-category and account are chosen on the cash entry screens. Remembered on this device.
enum CashSelectionStyle: String, CaseIterable {
    case badges, dropdown

    static let storageKey = "cashEntry.selectionStyle"

    var title: String { self == .badges ? "Badges" : "Dropdown" }
}

/// Toolbar menu to switch between the badge (chip) layout and dropdown menus. Both screens read the same stored choice.
struct CashSelectionStyleMenu: View {
    @Binding var style: CashSelectionStyle

    var body: some View {
        Menu {
            Picker("Selection style", selection: $style) {
                ForEach(CashSelectionStyle.allCases, id: \.self) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Image(systemName: style == .badges ? "square.grid.2x2" : "list.bullet")
        }
        .accessibilityLabel("Selection style: \(style.title)")
    }
}

/// One dropdown: a labelled row showing the current choice that opens a menu of options.
private struct CashDropdownRow<Options: View>: View {
    @Environment(\.maniTheme) private var theme
    let title: String
    let value: String
    @ViewBuilder let options: () -> Options

    var body: some View {
        Menu {
            options()
        } label: {
            HStack {
                Text(title)
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.base.textSecondary)
                Spacer()
                Text(value)
                    .foregroundStyle(theme.base.text)
                ManiSwiftUIComponents.IconView(.chevronDown, size: 12, color: theme.base.textSecondary)
            }
            .padding(.horizontal, ManiSpacing.md)
            .frame(minHeight: 48)
            .background(theme.base.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.base.border, lineWidth: 1))
        }
    }
}

/// Category and sub-category choices for a cash entry, shared by the add and edit screens.
struct CashCategoryPicker: View {
    let style: CashSelectionStyle
    let categories: [CashflowCategory]
    let category: CashflowCategory
    let subCategories: [CashflowSubCategory]
    let subCategory: CashflowSubCategory
    let onCategory: (CashflowCategory) -> Void
    let onSubCategory: (CashflowSubCategory) -> Void

    var body: some View {
        switch style {
        case .badges: badges
        case .dropdown: dropdowns
        }
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.sm) {
            SectionHeader(title: "Category")
            FlowLayout {
                ForEach(categories, id: \.self) { option in
                    ManiChip(option.rawValue, isSelected: option == category) { onCategory(option) }
                }
            }
            if !subCategories.isEmpty {
                SectionHeader(title: "Sub-category")
                FlowLayout {
                    ForEach(subCategories, id: \.self) { option in
                        ManiChip(option.rawValue, isSelected: option == subCategory) { onSubCategory(option) }
                    }
                }
            }
        }
    }

    private var dropdowns: some View {
        VStack(spacing: ManiSpacing.sm) {
            CashDropdownRow(title: "Category", value: category.rawValue) {
                ForEach(categories, id: \.self) { option in
                    Button(option.rawValue) { onCategory(option) }
                }
            }
            if !subCategories.isEmpty {
                CashDropdownRow(title: "Sub-category", value: subCategory.rawValue) {
                    ForEach(subCategories, id: \.self) { option in
                        Button(option.rawValue) { onSubCategory(option) }
                    }
                }
            }
        }
    }
}

/// Which account a cash entry touches: "To account" for cash in, "From account" for cash out.
struct CashAccountPicker: View {
    let style: CashSelectionStyle
    let title: String
    let accounts: [Account]
    let selectedId: String?
    let onSelect: (String) -> Void

    var body: some View {
        if !accounts.isEmpty {
            switch style {
            case .badges:
                VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                    SectionHeader(title: title)
                    FlowLayout {
                        ForEach(accounts, id: \.id) { account in
                            ManiChip(account.name, isSelected: account.id == selectedId) { onSelect(account.id) }
                        }
                    }
                }
            case .dropdown:
                CashDropdownRow(title: title, value: accounts.first { $0.id == selectedId }?.name ?? "Select") {
                    ForEach(accounts, id: \.id) { account in
                        Button(account.name) { onSelect(account.id) }
                    }
                }
            }
        }
    }
}

extension CashflowTransaction {
    /// "Utilities › Rent", skipping parts the app doesn't recognise; nil when neither is known.
    var categoryPath: String? {
        var parts: [String] = []
        if category != .unknown { parts.append(category.rawValue) }
        if let sub = subCategory, sub != .unknown, sub.rawValue != category.rawValue { parts.append(sub.rawValue) }
        return parts.isEmpty ? nil : parts.joined(separator: " › ")
    }

    /// Second line of an entry row: category path, then direction, time and mode.
    var rowSubtitle: String {
        if isTransfer { return "\(categoryPath ?? "Internal Transfer") · \(timestamp.timeOnly)" }
        let direction = transactionType == .credit ? "In" : "Out"
        let mode = paymentMode == .cash ? "Cash" : "Bank"
        let detail = "\(direction) · \(timestamp.timeOnly) · \(mode)"
        guard let categoryPath else { return detail }
        return "\(categoryPath) · \(detail)"
    }
}

// MARK: - Cash entry (84)

public struct CashEntryView: View {
    @Bindable private var viewModel: CashEntryViewModel
    private let onDone: () -> Void
    @AppStorage(CashSelectionStyle.storageKey) private var style: CashSelectionStyle = .badges

    public init(viewModel: CashEntryViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            ManiSegmentedControl(selection: Binding(get: { viewModel.kind }, set: { viewModel.setKind($0) }),
                                 options: CashEntryViewModel.Kind.allCases.map { ($0, $0.title) })
            ManiHeroAmount("₹" + (viewModel.amountText.isEmpty ? "0" : viewModel.amountText), caption: viewModel.particulars)
            if viewModel.isTransfer {
                // One entry moves money from one account to another: both ids are saved on it.
                CashAccountPicker(style: style, title: "From account", accounts: viewModel.accounts,
                                  selectedId: viewModel.fromAccountId, onSelect: { viewModel.selectFromAccount($0) })
                CashAccountPicker(style: style, title: "To account", accounts: viewModel.accounts,
                                  selectedId: viewModel.toAccountId, onSelect: { viewModel.selectToAccount($0) })
                if viewModel.transferNeedsMoreAccounts {
                    ManiNote("A transfer needs at least two accounts. Add another account to the organization first.", kind: .warning)
                }
            } else {
                CashCategoryPicker(style: style, categories: viewModel.categories, category: viewModel.category,
                                   subCategories: viewModel.subCategories, subCategory: viewModel.subCategory,
                                   onCategory: { viewModel.selectCategory($0) }, onSubCategory: { viewModel.selectSubCategory($0) })
                CashAccountPicker(style: style, title: viewModel.accountTitle, accounts: viewModel.accounts,
                                  selectedId: viewModel.selectedAccountId, onSelect: { viewModel.selectAccount($0) })
            }
            ManiInputField(label: "Note (optional)", text: $viewModel.note,
                           placeholder: viewModel.isTransfer ? "Cash deposited at bank" : (viewModel.isIn ? "Owner added float" : "Ramesh Traders"))
            ManiKeypad { key in viewModel.amountText = key.apply(to: viewModel.amountText) }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save entry", isEnabled: viewModel.canSave) {
                Task { if await viewModel.save() { onDone() } }
            }
        }
        .navigationTitle("Cash entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { CashSelectionStyleMenu(style: $style) }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Edit cash entry

public struct CashEntryEditView: View {
    @Bindable private var viewModel: CashEntryEditViewModel
    private let onDone: () -> Void
    @State private var confirmsDelete = false
    @AppStorage(CashSelectionStyle.storageKey) private var style: CashSelectionStyle = .badges

    public init(viewModel: CashEntryEditViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            if viewModel.isLoaded {
                if let date = viewModel.date {
                    ScreenSubtitle(text: date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute()))
                }
                if viewModel.isTransfer {
                    ScreenSubtitle(text: "Internal transfer")
                } else {
                    ManiSegmentedControl(selection: $viewModel.isIn, options: [(true, "Cash in"), (false, "Cash out")])
                }
                ManiHeroAmount("₹" + (viewModel.amountText.isEmpty ? "0" : viewModel.amountText),
                               caption: viewModel.particulars.isEmpty ? "No particulars" : viewModel.particulars)
                ManiInputField(label: "Particulars", text: $viewModel.particulars, placeholder: "What was this for?")
                if viewModel.isTransfer {
                    CashAccountPicker(style: style, title: "From account", accounts: viewModel.accounts,
                                      selectedId: viewModel.fromAccountId, onSelect: { viewModel.selectFromAccount($0) })
                    CashAccountPicker(style: style, title: "To account", accounts: viewModel.accounts,
                                      selectedId: viewModel.toAccountId, onSelect: { viewModel.selectToAccount($0) })
                } else {
                    CashCategoryPicker(style: style, categories: viewModel.categories, category: viewModel.category,
                                       subCategories: viewModel.subCategories, subCategory: viewModel.subCategory,
                                       onCategory: { viewModel.selectCategory($0) }, onSubCategory: { viewModel.selectSubCategory($0) })
                    CashAccountPicker(style: style, title: viewModel.accountTitle, accounts: viewModel.accounts,
                                      selectedId: viewModel.selectedAccountId, onSelect: { viewModel.selectAccount($0) })
                }
                ManiKeypad { key in viewModel.amountText = key.apply(to: viewModel.amountText) }
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            if viewModel.isLoaded {
                VStack(spacing: ManiSpacing.sm) {
                    ManiButton("Save changes", isLoading: viewModel.isSaving, isEnabled: viewModel.canSave) {
                        Task { if await viewModel.save() { onDone() } }
                    }
                    ManiButton("Delete entry", kind: .outline, isEnabled: !viewModel.isSaving) { confirmsDelete = true }
                }
            }
        }
        .navigationTitle("Edit entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { CashSelectionStyleMenu(style: $style) }
        }
        .task { await viewModel.load() }
        .alert("Delete this entry?", isPresented: $confirmsDelete) {
            Button("Delete", role: .destructive) {
                Task { if await viewModel.delete() { onDone() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is removed from the day's cash and the cash book. This can't be undone from the app.")
        }
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
            #if os(Android)  // SkipSwiftUI's DatePicker has no date range, so future dates aren't blocked here.
            DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
            #else
            DatePicker("Date", selection: $viewModel.date, in: ...Date(), displayedComponents: .date)
            #endif
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
