//
//  InventoryView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct InventoryView: View {
    @Environment(\.maniTheme) private var theme

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
                LazyVStack(spacing: ManiSpacing.md) {

                    Text(viewModel.lastSyncedText)
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.base.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, ManiSpacing.lg)
                        .padding(.top, ManiSpacing.sm)

                    // Stats section
                    LazyVGrid(columns: columns, spacing: ManiSpacing.md) {
                        ManiKPITile(title: "Total Items", value: viewModel.itemsCount.string)
                        ManiKPITile(title: "Hot Items", value: viewModel.hotItemsCount.string)
                        ManiKPITile(title: "Items Sold", value: viewModel.totalItemsSold.string)
                        ManiKPITile(title: "Amount Sold", value: viewModel.totalSoldAmount.string, isHighlighted: true)
                    }
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.lg)
                    .padding(.bottom, ManiSpacing.sm)

                    if viewModel.rows.isEmpty {
                        ManiNote("No inventory items found.", kind: .warning)
                            .padding(.horizontal, ManiSpacing.lg)
                            .padding(.top, ManiSpacing.lg)
                    } else {
                        ForEach(viewModel.rows) { row in
                            InventoryItemCardRowView(row: row)
                        }
                    }
                }
                .padding(.bottom, ManiSpacing.lg)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
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

// MARK: - Subviews

struct InventoryItemCardRowView: View {
    @Environment(\.maniTheme) private var theme

    let row: InventoryItemRow

    var body: some View {
        ManiCard {
            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                ManiListRow(
                    title: row.item.name,
                    status: row.item.isHotkey ? ("Hot", .warning) : nil
                )

                Divider().overlay(theme.base.border)

                ManiBreakdownRow(label: "Stock", value: row.item.currentStock.string)
                ManiBreakdownRow(label: "Items Sold", value: row.itemsSold.string)
                ManiBreakdownRow(label: "Sold Amount", value: row.soldValue.string, emphasis: .total)

                Divider().overlay(theme.base.border)

                ManiBreakdownRow(label: "Last Sold", value: row.item.lastSoldDateString)
                ManiBreakdownRow(label: "Updated At", value: row.item.updatedAtString)
            }
        }
        .padding(.horizontal, ManiSpacing.lg)
    }
}
