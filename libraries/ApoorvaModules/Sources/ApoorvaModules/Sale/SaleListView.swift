//
//  SaleListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import SwiftUI
import ApoorvaModels

public struct SaleListView: View {
    
    @Bindable var viewModel: SaleListViewModel
    
    public init(viewModel: SaleListViewModel) {
        self.viewModel = viewModel
    }
    
    // Grid layout for top stats
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
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
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Modernized Stats Section
                    LazyVGrid(columns: columns, spacing: 12) {
                        ModernStatBox(title: "Total Sales", value: viewModel.totalSalesCount.string)
                        ModernStatBox(title: "Revenue", value: viewModel.totalSubtotal.string)
                        ModernStatBox(title: "Received", value: viewModel.totalNetPayable.string)
                        ModernStatBox(title: "Total Discount", value: viewModel.totalDiscount.string)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    if viewModel.sales.isEmpty {
                        Text("No sales found for this period.")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(viewModel.sales) { sale in
                            SaleCardRowView(sale: sale)
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
                        await viewModel.forceSync()
                    }
                }) {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Filter By", selection: $viewModel.dateFilter) {
                        ForEach(SaleDateFilterOption.allCases, id: \.self) { option in
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
                        ForEach(SaleSortOption.allCases, id: \.self) { option in
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
    }
}

// MARK: - Modern Subviews

struct ModernStatBox: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

struct SaleCardRowView: View {
    
    let sale: Sale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Customer & Date
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sale.customerName.isEmpty ? "Unknown" : sale.customerName)
                        .font(.headline)
                    
                    if !sale.customerPhone.isEmpty {
                        Text(sale.customerPhone)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text(sale.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Divider()
            
            // Footer: Financials
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sub Total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(sale.subtotal.string)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discount")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(sale.overallDiscountAmount.string)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Net Pay")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(sale.netPayable.string)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.green)
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
