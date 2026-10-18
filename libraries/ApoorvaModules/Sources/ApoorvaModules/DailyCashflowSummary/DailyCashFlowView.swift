// DailyCashFlowView.swift
import Foundation
import SwiftUI
import ApoorvaModels

public struct DailyCashFlowView: View {
    
    @Bindable var viewModel: DailyCashFlowViewModel
    
    @State private var showAddUpdateSheet = false
    
    var makeAddUpdateViewModel: (Date, DailyCashflowSummary?) -> AddUpdateDailyCashflowSummaryViewModel
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    public init(viewModel: DailyCashFlowViewModel,
                makeAddUpdateViewModel: @escaping (Date, DailyCashflowSummary?) -> AddUpdateDailyCashflowSummaryViewModel) {
        self.viewModel = viewModel
        self.makeAddUpdateViewModel = makeAddUpdateViewModel
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
                    // Resetting font to ensure DatePicker text isn't massive from HomeView
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
                    if let summary = viewModel.summary {
                        
                        // Opening Balance Section
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
                        
                        // Transactions Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transactions")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal)
                        }
                        
                        // Closing Balance Section
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
                        
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("No summary recorded for this date.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 80)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddUpdateSheet = true }) {
                    // Explicitly setting the font to .body overrides the .largeTitle cascading from HomeView[cite: 43]
                    Image(systemName: viewModel.summary == nil ? "plus.circle.fill" : "pencil.circle.fill")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .sheet(isPresented: $showAddUpdateSheet, onDismiss: {
            Task { await viewModel.fetchSummary() }
        }) {
            AddUpdateDailyCashflowSummaryView(
                viewModel: makeAddUpdateViewModel(viewModel.selectedDate, viewModel.summary)
            )
        }
        .task {
            await viewModel.fetchSummary()
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
    
    // Auto-selects a relevant SF Symbol based on the account name (shared logic with Add/Update view)[cite: 42]
    private func iconName(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("cash") { return "banknote" }
        if lowercased.contains("upi") || lowercased.contains("pay") { return "qrcode.viewfinder" }
        if lowercased.contains("card") { return "creditcard" }
        return "building.columns"
    }
}
