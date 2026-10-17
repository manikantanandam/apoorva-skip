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
                ForEach(viewModel.items) { item in
                    InventoryItemCardView(item: item)
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


struct InventoryItemCardView: View {
    
    let item: InventoryItem
    
    var body: some View {
        CardView {
            VStack {
                HStack {
                    LabelView(text: item.name)
                    Spacer()
                    LabelView(text: item.currentStock.string,
                              style: .footnote)
                }
                HStack {
                    LabelView(text: "Last Sold", style: .caption)
                    Spacer()
                    LabelView(text: item.lastSoldDateString,
                              style: .caption)
                }
                
                HStack {
                    LabelView(text: "Updated at", style: .caption)
                    Spacer()
                    LabelView(text: item.updatedAtString,
                              style: .caption)
                }
                
                
            }
        }
        
    }
}
