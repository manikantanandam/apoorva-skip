//
//  CashflowListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

public struct CashflowTransactionListView: View {
    @Environment(\.maniTheme) private var theme

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
                .background(theme.base.surface)
            }

            // Horizontal Filter Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ManiSpacing.sm) {
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
                .padding(.horizontal, ManiSpacing.lg)
                .padding(.vertical, ManiSpacing.sm)
            }
            .background(theme.base.background)

            ScrollView {
                LazyVStack(spacing: ManiSpacing.md) {
                    ManiKPITile(title: "Total Transactions", value: viewModel.transactions.count.string, isHighlighted: true)
                        .padding(.horizontal, ManiSpacing.lg)
                        .padding(.top, ManiSpacing.sm)

                    if viewModel.transactions.isEmpty {
                        ManiNote("No transactions found for this period.", kind: .warning)
                            .padding(.horizontal, ManiSpacing.lg)
                            .padding(.top, ManiSpacing.lg)
                    } else {
                        ForEach(viewModel.transactions) { item in
                            CashflowCardRowView(item: item)
                        }
                    }
                }
                .padding(.bottom, ManiSpacing.lg)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
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

// MARK: - Subviews

struct CashflowCardRowView: View {
    @Environment(\.maniTheme) private var theme

    let item: CashflowTransaction

    var body: some View {
        ManiCard {
            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                ManiListRow(
                    title: item.category.rawValue,
                    subtitle: item.subCategory?.rawValue.isEmpty == false ? item.subCategory?.rawValue : nil,
                    value: item.amount.description,
                    status: (item.transactionType.rawValue, item.transactionType == .credit ? .success : .error)
                )

                Divider().overlay(theme.base.border)

                ManiBreakdownRow(label: "Mode", value: item.paymentMode.rawValue)
                ManiBreakdownRow(label: "Date", value: item.timestamp.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .padding(.horizontal, ManiSpacing.lg)
    }
}

/// Visually a chip, but used as a `Menu` label — the interaction itself
/// stays a native `Menu`/`Picker` since these are 4 independent filters,
/// not the single-selection set `ManiChipGroup` is built for.
struct FilterChip: View {
    @Environment(\.maniTheme) private var theme
    let title: String

    var body: some View {
        HStack(spacing: ManiSpacing.xs) {
            Text(title)
                .font(theme.typography.secondary)
            ManiSwiftUIComponents.IconView(.chevronDown, size: 10, color: theme.base.textSecondary)
        }
        .foregroundStyle(theme.base.text)
        .padding(.horizontal, ManiSpacing.md)
        .frame(minHeight: 32)
        .background(theme.base.surface)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(theme.base.border, lineWidth: 1))
    }
}
