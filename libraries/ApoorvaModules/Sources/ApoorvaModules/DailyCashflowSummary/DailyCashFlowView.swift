// DailyCashFlowView.swift
import Foundation
import SwiftUI
import ApoorvaModels

public struct DailyCashFlowView: View {
    
    @Bindable var viewModel: DailyCashFlowViewModel
    
    // Summary Sheet State
    @State private var showSummarySheet = false
    
    // Transaction Sheet State
    @State private var showTransactionSheet = false
    @State private var transactionToEdit: CashflowTransaction? = nil
    
    var makeAddUpdateSummaryViewModel: (Date, DailyCashflowSummary?) -> AddUpdateDailyCashflowSummaryViewModel
    
    // A closure to inject your Add/Update Transaction View from the ModulesContainer
    var makeAddUpdateTransactionView: (Date, CashflowTransaction?) -> AddUpdateCashflowTransactionViewModel
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    public init(viewModel: DailyCashFlowViewModel,
                makeAddUpdateSummaryViewModel: @escaping (Date, DailyCashflowSummary?) -> AddUpdateDailyCashflowSummaryViewModel,
                makeAddUpdateTransactionViewModel: @escaping (Date, CashflowTransaction?) -> AddUpdateCashflowTransactionViewModel) {
        self.viewModel = viewModel
        self.makeAddUpdateSummaryViewModel = makeAddUpdateSummaryViewModel
        self.makeAddUpdateTransactionView = makeAddUpdateTransactionViewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Modern Date Navigator
            HStack {
                Button(action: { viewModel.prevDate() }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                
                Spacer()
                
                DatePicker("Selected Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .font(.body)
                
                Spacer()
                
                Button(action: { viewModel.nextDate() }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
            
            // MARK: - Daily Content
            ScrollView {
                LazyVStack(spacing: 24) {
                    
                    // MARK: - Opening Balance Section
                    if let summary = viewModel.summary {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Opening Balance")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(summary.openingBalances) { accountBalance in
                                    ModernDailyStatBox(title: accountBalance.id, value: accountBalance.balance.description, color: .primary)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 24)
                    }
                    
                    // MARK: - Transactions Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Transactions")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            Spacer()
                            
                            Button(action: {
                                transactionToEdit = nil
                                showTransactionSheet = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.horizontal)
                        
                        if viewModel.transactions.isEmpty {
                            Text("No transactions recorded on this date.")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal)
                        } else {
                            ForEach(viewModel.transactions) { item in
                                CashflowCardRowView(item: item)
                                    .contextMenu {
                                        Button {
                                            transactionToEdit = item
                                            showTransactionSheet = true
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteTransaction(id: item.id)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.top, viewModel.summary == nil ? 24 : 0)
                    
                    // MARK: - Closing Balance Section
                    if let summary = viewModel.summary {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Closing Balance")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(summary.closingBalances) { accountBalance in
                                    ModernDailyStatBox(title: accountBalance.id, value: accountBalance.balance.description, color: .primary)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 32)
                    } else if !viewModel.isLoading {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("No summary recorded for this date.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    }
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showSummarySheet = true }) {
                    Image(systemName: viewModel.summary == nil ? "plus.square.dashed" : "pencil.and.list.clipboard")
                }
                .font(.system(size: 17, weight: .semibold))
            }
        }
        // Summary Sheet
        .sheet(isPresented: $showSummarySheet, onDismiss: {
            Task { await viewModel.fetchData() }
        }) {
            AddUpdateDailyCashflowSummaryView(
                viewModel: makeAddUpdateSummaryViewModel(viewModel.selectedDate, viewModel.summary)
            )
        }
        // Transaction Sheet
        .sheet(isPresented: $showTransactionSheet, onDismiss: {
            Task { await viewModel.fetchData() }
        }) {
            AddUpdateCashflowTransactionView(
                viewModel: makeAddUpdateTransactionView(viewModel.selectedDate, transactionToEdit)

            )
        }
        .task {
            await viewModel.fetchData()
        }
    }
}

// MARK: - Modern Subviews

struct ModernDailyStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: iconName(for: title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Text(value)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
    }
    
    private func iconName(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("cash") { return "banknote" }
        if lowercased.contains("upi") || lowercased.contains("pay") { return "qrcode.viewfinder" }
        if lowercased.contains("card") { return "creditcard" }
        return "building.columns"
    }
}
