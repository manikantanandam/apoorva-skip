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
    
    // Grid layout for top stats
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    public init(viewModel: InventoryViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    
                    // Modernized Stats Section
                    LazyVGrid(columns: columns, spacing: 12) {
                        InventoryStatBox(title: "Total Items", value: viewModel.itemsCount.string)
                        InventoryStatBox(title: "Hot Items", value: viewModel.hotItemsCount.string)
                        InventoryStatBox(title: "Items Sold", value: viewModel.totalItemsSold.string)
                        InventoryStatBox(title: "Amount Sold", value: viewModel.totalSoldAmount.string)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    if viewModel.rows.isEmpty {
                        Text("No inventory items found.")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(viewModel.rows) { row in
                            InventoryItemCardRowView(row: row)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .toolbar {
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

// MARK: - Modern Subviews

struct InventoryStatBox: View {
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

struct InventoryItemCardRowView: View {
    
    let row: InventoryItemRow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Item Name & Hotkey Indicator
            HStack(alignment: .top) {
                Text(row.item.name)
                    .font(.headline)
                
                Spacer()
                
                if row.item.isHotkey {
                    Image(systemName: "star.fill")
                        .foregroundColor(.red)
                        .font(.body)
                }
            }
            
            Divider()
            
            // Middle: Core Metrics
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(row.item.currentStock.string)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items Sold")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(row.itemsSold.string)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Sold Amount")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(row.soldValue.string)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.green)
                }
            }
            
            Divider()
            
            // Footer: Dates
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Sold")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(row.item.lastSoldDateString)
                        .font(.caption)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Updated At")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(row.item.updatedAtString)
                        .font(.caption)
                        .foregroundStyle(.primary)
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
