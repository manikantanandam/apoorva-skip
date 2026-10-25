//
//  CashflowListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import SwiftUI
import ApoorvaModels
struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

public struct CashflowTransactionListView: View {
    
    @Bindable var viewModel: CashflowTransactionListViewModel
    
    // State for CSV Export
    @State private var exportItem: ExportItem?
    
    // Grid layout for top stats
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
        
    public init(viewModel: CashflowTransactionListViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            
            // Custom Date Picker Section
            if viewModel.dateFilter == .custom {
                HStack {
                    DatePicker("Start", selection: $viewModel.customStartDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("to")
                        .foregroundColor(.secondary)
                    DatePicker("End", selection: $viewModel.customEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
            }
            
            // Horizontal Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Type Filter
                    Menu {
                        Picker("Type", selection: $viewModel.typeFilter) {
                            ForEach(CashflowTypeFilterOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        FilterChip(title: viewModel.typeFilter == .all ? "Type" : viewModel.typeFilter.rawValue)
                    }
                    
                    // Payment Mode Filter
                    Menu {
                        Picker("Mode", selection: $viewModel.paymentModeFilter) {
                            ForEach(CashflowPaymentModeFilterOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        FilterChip(title: viewModel.paymentModeFilter == .all ? "Mode" : viewModel.paymentModeFilter.rawValue)
                    }
                    
                    // Category Filter
                    Menu {
                        Picker("Category", selection: $viewModel.categoryFilter) {
                            ForEach(viewModel.availableCategories, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    } label: {
                        FilterChip(title: viewModel.categoryFilter == "All" ? "Category" : viewModel.categoryFilter)
                    }
                    
                    // SubCategory Filter
                    Menu {
                        Picker("Subcategory", selection: $viewModel.subCategoryFilter) {
                            ForEach(viewModel.availableSubCategories, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                    } label: {
                        FilterChip(title: viewModel.subCategoryFilter == "All" ? "Subcategory" : viewModel.subCategoryFilter)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .background(Color(UIColor.systemGroupedBackground))
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ModernStatBox(title: "Total Transactions", value: viewModel.transactions.count.string)
                    
                    if viewModel.transactions.isEmpty {
                        Text("No transactions found for this period.")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(viewModel.transactions) { item in
                            CashflowCardRowView(item: item)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.update()
                    }
                }) {
                    Label("Update", systemImage: "arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    if let url = viewModel.generateCSV() {
                        // FIX: Assign directly to the new ExportItem struct to trigger the sheet
                        exportItem = ExportItem(url: url)
                    }
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter By", selection: $viewModel.dateFilter) {
                        ForEach(CashflowDateFilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.forceSync()
                    }
                }) {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(CashflowTransactionSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .task {
            await viewModel.prepareDate()
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }
}

// MARK: - Modern Subviews

struct CashflowCardRowView: View {
    
    let item: CashflowTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Category & Date
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.category.rawValue)
                        .font(.headline)
                    
                    if let subCategory = item.subCategory?.rawValue, !subCategory.isEmpty {
                        Text(subCategory)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Divider()
            
            // Footer: Details & Amount
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type & Mode")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(item.transactionType.rawValue) • \(item.paymentMode.rawValue)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Amount")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.amount.description)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        // Optional: you can color code based on type (e.g., item.transactionType == .income ? .green : .primary)
                        .foregroundStyle(item.transactionType == .credit ? Color.green : Color.red)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}

struct FilterChip: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            Image(systemName: "chevron.down")
                .font(.caption2)
        }
        .font(.subheadline)
        .foregroundColor(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}
