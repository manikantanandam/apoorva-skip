//
//  DailyCashflowListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 24/10/26.
//

import SwiftUI
import ApoorvaUtilities
import ApoorvaModels
import UIKit

public struct DailyCashflowListView: View {
    
    @Bindable var viewModel: DailyCashFlowListViewModel
    
    var makeDailyCashFlowView: (Date) -> DailyCashFlowView
    
    public init(viewModel: DailyCashFlowListViewModel,
                @ViewBuilder makeDailyCashFlowView: @escaping (Date) -> DailyCashFlowView) {
        self.viewModel = viewModel
        self.makeDailyCashFlowView = makeDailyCashFlowView
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            
            // Dashboard Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    dashboardCard(title: "Shop Setup", value: viewModel.shopSetupTotal, color: .orange, icon: "building.2")
                    dashboardCard(title: "Money In", value: viewModel.totalIncome, color: .green, icon: "arrow.down.left.circle")
                    dashboardCard(title: "Money Out", value: viewModel.totalExpense, color: .red, icon: "arrow.up.right.circle")
                    dashboardCard(title: "Inventory", value: viewModel.inventoryTotal, color: .blue, icon: "shippingbox")
                    dashboardCard(
                        title: viewModel.profitOrLoss >= 0 ? "Profit" : "Loss",
                        value: abs(viewModel.profitOrLoss),
                        color: viewModel.profitOrLoss >= 0 ? .green : .red,
                        icon: "chart.line.uptrend.xyaxis",
                        prefix: viewModel.profitOrLoss >= 0 ? "+" : "-"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            
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
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Loop through the summaries provided by the view model[cite: 26, 27]
                    ForEach(viewModel.summaries, id: \.id) { summary in
                        // 3. Wrap the card in a NavigationLink passing the summary's date
                        NavigationLink(destination: makeDailyCashFlowView(summary.date)) {
                            cashflowCard(for: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
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
            await viewModel.fetchData() // Fetch data on load
        }
    }
    
    @ViewBuilder
    private func dashboardCard(title: String, value: Double, color: Color, icon: String, prefix: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.subheadline)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("\(prefix)\(value.string)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .padding(12)
        .frame(minWidth: 120, alignment: .leading)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 3, x: 0, y: 2)
    }
    
    // Extracted into a separate view builder for cleaner code
    @ViewBuilder
    private func cashflowCard(for summary: DailyCashflowSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header: Date and ID
            HStack {
                
                Spacer()
                
                Text("#\(summary.id.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.tertiarySystemFill)) // Adapts better to dark mode
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Body: Opening and Closing Balances[cite: 27]
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opening")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(summary.totalOpening.string)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Closing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(summary.totalClosing.string)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green) // Highlights the final daily amount
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
                )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}
