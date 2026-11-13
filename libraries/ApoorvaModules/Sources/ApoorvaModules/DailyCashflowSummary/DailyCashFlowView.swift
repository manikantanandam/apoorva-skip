// DailyCashFlowView.swift
import Foundation
import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents
import ManiLogger

private let logger = AppLogger(category: .ui)

enum TransactionSheetAction: Identifiable {
    case add
    case edit(CashflowTransaction)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let tx): return tx.id
        }
    }
    
    var transaction: CashflowTransaction? {
        if case .edit(let tx) = self { return tx }
        return nil
    }
}

enum SummarySheetAction: Identifiable {
    case present(Date, DailyCashflowSummary?)
    
    var id: String {
        switch self {
        case .present(let date, let summary):
            return summary?.id ?? date.description
        }
    }
}

public struct DailyCashFlowView: View {
    @Environment(\.maniTheme) private var theme

    @Bindable var viewModel: DailyCashFlowViewModel
    
    // Summary Sheet State
    @State private var activeSummarySheet: SummarySheetAction? = nil
    
    // Transaction Sheet State
    @State private var activeTransactionSheet: TransactionSheetAction? = nil
    
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
                        .foregroundStyle(theme.base.textSecondary.opacity(0.5))
                }
                
                Spacer()
                
                DatePicker("Selected Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .font(.body)
                    .onChange(of: viewModel.selectedDate) { _, _ in
                        Task { await viewModel.fetchData() }
                    }
                
                Spacer()
                
                Button(action: { viewModel.nextDate() }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.base.textSecondary.opacity(0.5))
                }
            }
            .padding(.horizontal, ManiSpacing.lg)
            .padding(.vertical, ManiSpacing.md)
            .background(theme.base.surface)
            
            // MARK: - Daily Content
            ScrollView {
                LazyVStack(spacing: 24) {
                    
                    // MARK: - Opening Balance Section
                    if let summary = viewModel.currentSummary {
                        VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                            Text("Opening Balance")
                                .font(theme.typography.secondary.weight(.bold))
                                .foregroundStyle(theme.base.textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, ManiSpacing.lg)

                            LazyVGrid(columns: columns, spacing: ManiSpacing.md) {
                                ForEach(summary.openingBalances) { accountBalance in
                                    ManiKPITile(title: accountBalance.name, value: accountBalance.balance.description)
                                }
                            }
                            .padding(.horizontal, ManiSpacing.lg)
                        }
                        .padding(.top, ManiSpacing.lg)
                    }
                    
                    // MARK: - Transactions Section
                    VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                        HStack {
                            Text("Transactions")
                                .font(theme.typography.secondary.weight(.bold))
                                .foregroundStyle(theme.base.textSecondary)
                                .textCase(.uppercase)

                            Spacer()
                            if viewModel.currentSummary?.locked != true {
                                Button(action: {
                                    activeTransactionSheet = .add
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundStyle(theme.accent.accent)
                                }
                            }
                        }
                        .padding(.horizontal, ManiSpacing.lg)

                        if viewModel.transactions.isEmpty {
                            Text("No transactions recorded on this date.")
                                .font(theme.typography.secondary)
                                .foregroundStyle(theme.base.textSecondary)
                                .padding(.horizontal, ManiSpacing.lg)
                        } else {
                            ForEach(viewModel.transactions) { item in
                                CashflowCardRowView(item: item)
                                    .onTapGesture {
                                        if viewModel.currentSummary?.locked != true {
                                            activeTransactionSheet = .edit(item)
                                        }
                                    }
                                    .contextMenu {
                                        Button {
                                            activeTransactionSheet = .edit(item)
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
                    .padding(.top, viewModel.currentSummary == nil ? 24 : 0)
                    
                    // MARK: - Closing Balance Section
                    if let summary = viewModel.currentSummary {
                        VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                            Text("Closing Balance")
                                .font(theme.typography.secondary.weight(.bold))
                                .foregroundStyle(theme.base.textSecondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, ManiSpacing.lg)

                            LazyVGrid(columns: columns, spacing: ManiSpacing.md) {
                                ForEach(summary.closingBalances) { accountBalance in
                                    ManiKPITile(title: accountBalance.name, value: accountBalance.balance.description, isHighlighted: true)
                                }
                            }
                            .padding(.horizontal, ManiSpacing.lg)
                        }
                        .padding(.bottom, ManiSpacing.xl)
                    } else if !viewModel.isLoading {
                        ManiNote("No summary recorded for this date.", kind: .info)
                            .padding(.horizontal, ManiSpacing.lg)
                            .padding(.top, ManiSpacing.xl)
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, ManiSpacing.xl)
                    }
                }
            }
        }
        .background(theme.base.background.ignoresSafeArea())
        .toolbar {
            if let summary = viewModel.currentSummary, !summary.locked {
                
                ToolbarItem(placement: .primaryAction) {
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            Task { await viewModel.toggleLockStatus() }
                        }) {
                            if summary.locked {
                                ManiSwiftUIComponents.IconView(.lock, size: 17, color: theme.base.error)
                            } else {
                                Image(systemName: "lock.open")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(theme.base.success)
                            }
                        }
                        
                        Button(action: {
                            activeSummarySheet = .present(viewModel.selectedDate, viewModel.currentSummary)
                        }) {
                            Image(systemName: viewModel.currentSummary == nil ? "plus.square.dashed" : "pencil.and.list.clipboard")
                        }
                    }
                    
                        
                        .font(.system(size: 17, weight: .semibold))
            }
        }
        }
        // Summary Sheet
        .sheet(item: $activeSummarySheet, onDismiss: {
            Task {
                logger.debug("Add/Update Daily Summary dismissed; refetching data")
                await viewModel.refreshData()
            }
        }) { action in
            switch action {
            case .present(let date, let summary):
                AddUpdateDailyCashflowSummaryView(
                    viewModel: makeAddUpdateSummaryViewModel(date, summary),
                    makeAddUpdateTransactionViewModel: makeAddUpdateTransactionView
                )
            }
        }
        .sheet(item: $activeTransactionSheet, onDismiss: {
            Task { await viewModel.refreshData() }
        }) { actionContext in
            AddUpdateCashflowTransactionView(
                // Use actionContext.transaction which dynamically unpacks the item or nil
                viewModel: makeAddUpdateTransactionView(viewModel.selectedDate, actionContext.transaction)
            )
        }
        .task {
            await viewModel.fetchData()
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
}

