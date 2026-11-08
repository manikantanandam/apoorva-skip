//
//  DailyCashflowListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 24/10/26.
//

import SwiftUI
import ApoorvaUtilities
import ApoorvaModels
import ManiSwiftUIComponents

public struct DailyCashflowListView: View {
    @Environment(\.maniTheme) private var theme

    @Bindable var viewModel: DailyCashFlowListViewModel

    var onSelectDate: (Date) -> Void

    public init(viewModel: DailyCashFlowListViewModel,
                onSelectDate: @escaping (Date) -> Void) {
        self.viewModel = viewModel
        self.onSelectDate = onSelectDate
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            
            // Dashboard Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ManiSpacing.sm) {
                    dashboardCard(title: "Shop Setup", value: viewModel.shopSetupTotal)
                    dashboardCard(title: "Money In", value: viewModel.totalIncome)
                    dashboardCard(title: "Money Out", value: viewModel.totalExpense)
                    dashboardCard(title: "Inventory", value: viewModel.inventoryTotal)
                    dashboardCard(
                        title: viewModel.profitOrLoss >= 0 ? "Profit" : "Loss",
                        value: abs(viewModel.profitOrLoss),
                        prefix: viewModel.profitOrLoss >= 0 ? "+" : "-",
                        isHighlighted: true
                    )
                }
                .padding(.horizontal, ManiSpacing.lg)
                .padding(.vertical, ManiSpacing.md)
            }
            .background(theme.base.surface)

            // Custom Date Picker Section
            if viewModel.dateFilter == .custom {
                HStack {
                    DatePicker("Start", selection: $viewModel.customStartDate, displayedComponents: .date)
                        .labelsHidden()
                    Text("to")
                        .foregroundStyle(theme.base.textSecondary)
                    DatePicker("End", selection: $viewModel.customEndDate, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding()
                .background(theme.base.surface)
            }

            ScrollView {
                LazyVStack(spacing: ManiSpacing.md) {
                    // Loop through the summaries provided by the view model[cite: 26, 27]
                    ForEach(viewModel.summaries, id: \.id) { summary in
                        Button {
                            onSelectDate(summary.date)
                        } label: {
                            cashflowCard(for: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, ManiSpacing.lg)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
        .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Filter By", selection: $viewModel.dateFilter) {
                                ForEach(DailyCashflowDateFilterOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Sort By", selection: $viewModel.sortOption) {
                                ForEach(DailyCashflowSortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
        .task {
            print("Daily Cashflow List View task")
            await viewModel.fetchData() // Fetch data on load
        }
    }
    
    @ViewBuilder
    private func dashboardCard(title: String, value: Double, prefix: String = "", isHighlighted: Bool = false) -> some View {
        ManiKPITile(title: title, value: "\(prefix)\(value.string)", isHighlighted: isHighlighted)
            .frame(minWidth: 120, alignment: .leading)
    }

    // Extracted into a separate view builder for cleaner code
    @ViewBuilder
    private func cashflowCard(for summary: DailyCashflowSummary) -> some View {
        ManiCard {
            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                HStack {
                    Spacer()
                    ManiStatusBadge("#\(summary.id.prefix(8))", kind: .neutral)
                }

                Divider().overlay(theme.base.border)

                ManiBreakdownRow(label: "Opening", value: summary.totalOpening.string)
                ManiBreakdownRow(label: "Closing", value: summary.totalClosing.string, emphasis: .total)
            }
        }
        .padding(.horizontal, ManiSpacing.lg)
    }
}
