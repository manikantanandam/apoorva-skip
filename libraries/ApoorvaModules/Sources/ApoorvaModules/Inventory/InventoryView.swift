//
//  InventoryView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import SwiftUI
import ApoorvaModels

public struct InventoryView: View {
    
    @Bindable var viewModel: InventoryViewModel
    
    public init(viewModel: InventoryViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack {
                VStack {
                    HStack {
                        CardStatView(title: "Total", value: viewModel.itemsCount.string)
                        CardStatView(title: "Hot Items", value: viewModel.hotItemsCount.string)
                    }
                    HStack {
                        CardStatView(title: "Items Sold", value: viewModel.totalItemsSold.string)
                        CardStatView(title: "Amount Sold", value: viewModel.totalSoldAmount.string)
                    }
                }
                ForEach(viewModel.rows) { row in
                    InventoryItemCardRowView(row: row)
                }
            }
        }
        .toolbar{
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(InventorySortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
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
        }
        .task {
            await viewModel.prepareDate()
        }
    }
}


struct InventoryItemCardRowView: View {
    
    let row: InventoryItemRow
    
    var body: some View {
        CardView {
            VStack {
                HStack {
                    LabelView(text: row.item.name)
                    Spacer()
                    if row.item.isHotkey {
                        IconView(icon: .star, iconSize: 24, color: .red)
                    }
                }
                HStack {
                    CardStatView(title: "Stock", value: row.item.currentStock.string, style: .info)
                    CardStatView(title: "Items Sold", value: row.itemsSold.string, style: .info)
                    CardStatView(title: "Sold Amount", value: row.soldValue.string, style: .info)
                    Spacer()
                }
                HStack {
                    LabelView(text: "Last Sold", style: .caption)
                    Spacer()
                    LabelView(text: row.item.lastSoldDateString,
                              style: .caption)
                }
                
                HStack {
                    LabelView(text: "Updated at", style: .caption)
                    Spacer()
                    LabelView(text: row.item.updatedAtString,
                              style: .caption)
                }
                
                
            }
        }
        
    }
}
