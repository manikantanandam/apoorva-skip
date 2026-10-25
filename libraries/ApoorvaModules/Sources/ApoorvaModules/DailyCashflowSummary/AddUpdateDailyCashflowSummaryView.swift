// AddUpdateDailyCashflowSummaryView.swift
import SwiftUI
import ApoorvaModels
import UIKit

public struct AddUpdateDailyCashflowSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddUpdateDailyCashflowSummaryViewModel
    
    // 1. ADD SHEET STATE
    @State private var showTransactionSheet = false
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
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "calendar")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.blue)
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
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.dayTransactions) { tx in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(tx.category.rawValue)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                Text(tx.particulars)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(String(format: "%.2f", tx.amount))
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(tx.transactionType == .credit ? .green : .red)
                                        }
                                        
                                        .contentShape(Rectangle()) // Ensures the whole row is tappable
                                        .onTapGesture {
                                            transactionToEdit = tx
                                            showTransactionSheet = true
                                        }
                                        
                                        if tx.id != viewModel.dayTransactions.last?.id {
                                            Divider().opacity(0.5)
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
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
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
                    ZStack {
                        Color(.systemBackground).opacity(0.6).ignoresSafeArea()
                        ProgressView()
                            .padding(24)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 10)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showTransactionSheet, onDismiss: {
                Task { await viewModel.fetchInitialData() }
            }) {
                AddUpdateCashflowTransactionView(
                    viewModel: makeAddUpdateTransactionViewModel(viewModel.date, transactionToEdit)
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
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 12, weight: .bold)) // Fixed font size
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            content
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct AccountBalanceInputRow: View {
    let accountName: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Contextual icon with a modern circular background badge
            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    .frame(width: 32, height: 32)
                
                Image(systemName: iconName(for: accountName))
                    .font(.system(size: 14, weight: .medium)) // Fixed size instead of flexible frame
                    .foregroundColor(.primary.opacity(0.7))
            }
            
            Text(accountName)
                .font(.system(size: 16, weight: .medium)) // Fixed size to block cascade
                .foregroundColor(.primary)
            
            Spacer()
            
            TextField("0.0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 140)
        }
    }
    
    // Auto-selects a relevant SF Symbol (using filled variants for better contrast inside the circular badge)
    private func iconName(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("cash") { return "banknote.fill" }
        if lowercased.contains("upi") || lowercased.contains("pay") { return "qrcode.viewfinder" }
        if lowercased.contains("card") { return "creditcard.fill" }
        return "building.columns.fill"
    }
}
