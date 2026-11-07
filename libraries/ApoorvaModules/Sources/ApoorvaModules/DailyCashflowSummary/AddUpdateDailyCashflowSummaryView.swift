// AddUpdateDailyCashflowSummaryView.swift
import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct AddUpdateDailyCashflowSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.maniTheme) private var theme
    @Bindable var viewModel: AddUpdateDailyCashflowSummaryViewModel
    
    // 1. ADD SHEET STATE
    @State private var activeTransactionSheet: TransactionSheetAction? = nil
    @State private var transactionToEdit: CashflowTransaction? = nil
    
    var makeAddUpdateTransactionViewModel: (Date, CashflowTransaction?) -> AddUpdateCashflowTransactionViewModel
    
    public init(viewModel: AddUpdateDailyCashflowSummaryViewModel,
                makeAddUpdateTransactionViewModel: @escaping (Date, CashflowTransaction?) -> AddUpdateCashflowTransactionViewModel) {
        self.viewModel = viewModel
        self.makeAddUpdateTransactionViewModel = makeAddUpdateTransactionViewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Date Section
                    ModernFormCard(title: "Summary Date") {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(theme.accent.soft)
                                    .frame(width: 32, height: 32)
                                ManiSwiftUIComponents.IconView(.calendar, size: 14, color: theme.accent.accent)
                            }

                            DatePicker("Select Date", selection: $viewModel.date, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .font(.body) // Prevents cascading large fonts
                            Spacer()
                        }
                    }
                    
                    // MARK: - Opening Balances
                    if !viewModel.accounts.isEmpty {
                        ModernFormCard(title: "Opening Balance") {
                            VStack(spacing: 12) {
                                ForEach(viewModel.accounts, id: \.id) { account in
                                    AccountBalanceInputRow(
                                        accountName: account.name,
                                        text: bindingForOpening(accountId: account.id)
                                    )
                                    if account.id != viewModel.accounts.last?.id {
                                        Divider().opacity(0.5)
                                    }
                                }
                            }
                        }
                        
                        ModernFormCard(title: "Day Transactions (\(viewModel.dayTransactions.count))") {
                            if viewModel.dayTransactions.isEmpty {
                                Text("No transactions recorded for this date.")
                                    .font(theme.typography.secondary)
                                    .foregroundStyle(theme.base.textSecondary)
                                    .padding(.vertical, ManiSpacing.sm)
                            } else {
                                VStack(spacing: ManiSpacing.sm) {
                                    ForEach(viewModel.dayTransactions) { tx in
                                        ManiListRow(
                                            title: tx.category.rawValue,
                                            subtitle: tx.particulars,
                                            value: String(format: "%.2f", tx.amount),
                                            status: (tx.paymentMode.rawValue, tx.transactionType == .credit ? .success : .error),
                                            action: { activeTransactionSheet = .edit(tx) }
                                        )

                                        if tx.id != viewModel.dayTransactions.last?.id {
                                            Divider().overlay(theme.base.border)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Closing Balances
                        ModernFormCard(title: "Closing Balance") {
                            VStack(spacing: 12) {
                                ForEach(viewModel.accounts, id: \.id) { account in
                                    AccountBalanceInputRow(
                                        accountName: account.name,
                                        text: bindingForClosing(accountId: account.id)
                                    )
                                    .disabled(true)
                                    .opacity(0.6)
                                    if account.id != viewModel.accounts.last?.id {
                                        Divider().opacity(0.5)
                                    }
                                }
                            }
                        }
                    } else if viewModel.errorMessage == nil {
                        ProgressView("Loading accounts...")
                            .padding()
                    }
                    
                    // MARK: - Error Message
                    if let error = viewModel.errorMessage {
                        ManiNote(error, kind: .error)
                    }
                }
                .padding(ManiSpacing.lg)
            }
            .background(theme.base.background.ignoresSafeArea())
            .navigationTitle("Daily Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        // Explicitly restrict the size to block the HomeView font cascade
                        .font(.system(size: 17, weight: .regular))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
                        }
                    }
                    // Explicitly restrict the size and keep it bold
                    .font(.system(size: 17, weight: .bold))
                    .disabled(viewModel.isSaving || viewModel.accounts.isEmpty)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ProgressView()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(item: $activeTransactionSheet, onDismiss: {
                Task { await viewModel.fetchInitialData() }
            }) { actionContext in
                AddUpdateCashflowTransactionView(
                    viewModel: makeAddUpdateTransactionViewModel(viewModel.date, actionContext.transaction)
                )
            }
            .task {
                await viewModel.fetchInitialData()
            }
        }
    }
    
    // MARK: - Binding Helpers
    private func bindingForOpening(accountId: String) -> Binding<String> {
        Binding<String>(
            get: { viewModel.openingBalanceInputs[accountId] ?? "" },
            set: { viewModel.openingBalanceInputs[accountId] = $0 }
        )
    }
    
    private func bindingForClosing(accountId: String) -> Binding<String> {
            Binding<String>(
                get: { viewModel.closingBalanceInputs[accountId] ?? "" },
                set: { _ in } // Remain read-only so the user cannot override the calculated value
            )
        }
}

// MARK: - UI Components

struct ModernFormCard<Content: View>: View {
    @Environment(\.maniTheme) private var theme
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ManiCard {
            VStack(alignment: .leading, spacing: ManiSpacing.md) {
                Text(title)
                    .font(theme.typography.secondary.weight(.bold))
                    .foregroundStyle(theme.base.textSecondary)
                    .textCase(.uppercase)

                content
            }
        }
    }
}

struct AccountBalanceInputRow: View {
    @Environment(\.maniTheme) private var theme
    let accountName: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: ManiSpacing.md) {
            // Contextual icon with a themed circular background badge
            ZStack {
                Circle()
                    .fill(theme.accent.soft)
                    .frame(width: 32, height: 32)

                ManiSwiftUIComponents.IconView(icon(for: accountName), size: 14, color: theme.accent.accent)
            }

            Text(accountName)
                .font(theme.typography.body.weight(.medium))
                .foregroundStyle(theme.base.text)

            Spacer()

            TextField("0.0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(theme.typography.body.weight(.semibold))
                .foregroundStyle(theme.base.text)
                .padding(.vertical, ManiSpacing.sm)
                .padding(.horizontal, ManiSpacing.md)
                .background(theme.base.background)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.input, style: .continuous))
                .frame(width: 140)
        }
    }

    // Falls back to `.more` when no mapped icon exists for the account name
    // (ManiIconName has no bank/institution icon yet).
    private func icon(for name: String) -> ManiIconName {
        let lowercased = name.lowercased()
        if lowercased.contains("cash") { return .cash }
        if lowercased.contains("upi") || lowercased.contains("pay") { return .qrCode }
        if lowercased.contains("card") { return .card }
        return .more
    }
}
