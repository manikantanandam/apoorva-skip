//
//  CashflowListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import SwiftUI

public struct CashflowTransactionListView: View {
    
    @Bindable var viewModel: CashflowTransactionListViewModel
        
    public init(viewModel: CashflowTransactionListViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(viewModel.transactions) { item in
                    CardView {
                        VStack {

                            DescriptionView(
                                title: "Category",
                                value: "\(item.category)"
                            )
                            DescriptionView(
                                title: "Sub Category",
                                value: "\(item.subCategory ?? "")"
                            )
                            DescriptionView(
                                title: "Transaction Type",
                                value: "\(item.transactionType.rawValue)"
                            )
                            DescriptionView(
                                title: "Payment Mode",
                                value: "\(item.paymentMode.rawValue)"
                            )
                            DescriptionView(
                                title: "Person",
                                value: "\(item.person)"
                            )
                            DescriptionView(
                                title: "Amount",
                                value: "\(item.amount)"
                            )
                            DescriptionView(
                                title: "Cashflow Date",
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
                        await viewModel.update()
                    }
                }) {
                    Label("Update", systemImage: "arrow.up")
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
    }
}
