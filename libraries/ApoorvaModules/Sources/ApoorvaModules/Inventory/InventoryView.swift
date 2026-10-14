//
//  InventoryView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import SwiftUI

public struct InventoryView: View {
    
    @Bindable var viewModel: InventoryViewModel
    
    public init(viewModel: InventoryViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(viewModel.items) { item in
                    CardView {
                        VStack {
                            LabelView(text: item.name)
                            LabelView(text: "\(item.billMachineNumber)")
                            LabelView(text: "\(item.currentStock)")
                            DescriptionView(
                                title: "Last Sold Date",
                                value: item.lastSoldDate?.toString(format: "dd-MM-yyyy") ?? ""
                            )
                            DescriptionView(
                                title: "Last Updated Date",
                                value: item.updatedAt?.toString(format: "dd-MM-yyyy") ?? ""
                            )
                        }
                    }
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
