//
//  SaleListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import SwiftUI

public struct SaleListView: View {
    
    @Bindable var viewModel: SaleListViewModel
        
    public init(viewModel: SaleListViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(viewModel.sales) { item in
                    CardView {
                        VStack {
                            LabelView(text: item.customerName)
                            LabelView(text: item.customerPhone)
                            LabelView(text: item.status)
                            DescriptionView(
                                title: "Sub Total",
                                value: "\(item.subtotal)"
                            )
                            DescriptionView(
                                title: "Discount Amount",
                                value: "\(item.overallDiscountAmount)"
                            )
                            DescriptionView(
                                title: "Discount Percent",
                                value: "\(item.overallDiscountPercent)"
                            )
                            DescriptionView(
                                title: "Net Payable",
                                value: "\(item.netPayable)"
                            )
                            DescriptionView(
                                title: "Sale Date",
                                value: item.timestamp.toString(format: "dd-MM-yyyy")
                            )
                        }
                    }
                }
            }
        }
        .toolbar{
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
