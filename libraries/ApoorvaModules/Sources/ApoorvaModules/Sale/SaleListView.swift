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
                LazyVStack {
                    VStack {
                        HStack {
                            CardStatView(title: "Total Sales", value: viewModel.totalSalesCount.string)
                            CardStatView(title: "Revenue", value: viewModel.totalSubtotal.string)
                        }
                        HStack {
                            CardStatView(title: "Received", value: viewModel.totalNetPayable.string)
                            CardStatView(title: "Total Discount", value: viewModel.totalDiscount.string)
                        }
                    }
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
            }
        }
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


struct SaleCardRowView: View {
    
    let sale: Sale
    
    var body: some View {
        CardView {
            VStack(alignment: .leading) {
                HStack {
                    VStack {
                        LabelView(text: sale.customerName, style: .caption)
                        LabelView(text: sale.customerPhone, style: .caption)
                    }
                    Spacer()
                    LabelView(text: sale.timestamp.formatted(date: .abbreviated, time: .shortened),
                              style: .caption)
                }
                
                HStack {
                    CardStatView(
                        title: "Sub Total",
                        value: sale.subtotal.string,
                        style: .info
                    )
                    CardStatView(
                        title: "Discount",
                        value: sale.overallDiscountAmount.string,
                        style: .info
                    )
                    CardStatView(
                        title: "Net Pay",
                        value: sale.netPayable.string,
                        style: .info
                    )
                    Spacer()
                }
            }
        }
    }
}
