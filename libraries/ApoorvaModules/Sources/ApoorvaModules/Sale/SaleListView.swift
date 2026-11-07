//
//  SaleListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 16/10/26.
//

import Foundation
import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents
import UIKit

public struct SaleListView: View {
    @Environment(\.maniTheme) private var theme
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
                .background(theme.base.surface)
            }

            ScrollView {
                LazyVStack(spacing: ManiSpacing.md) {
                    // Stats section
                    LazyVGrid(columns: columns, spacing: ManiSpacing.md) {
                        ManiKPITile(title: "Total Sales", value: viewModel.totalSalesCount.string, isHighlighted: true)
                        ManiKPITile(title: "Revenue", value: viewModel.totalSubtotal.string)
                        ManiKPITile(title: "Received", value: viewModel.totalNetPayable.string)
                        ManiKPITile(title: "Total Discount", value: viewModel.totalDiscount.string)
                    }
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.lg)
                    .padding(.bottom, ManiSpacing.sm)

                    if viewModel.sales.isEmpty {
                        Text("No sales found for this period.")
                            .foregroundStyle(theme.base.textSecondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(viewModel.sales) { sale in
                            SaleCardRowView(sale: sale)
                        }
                    }
                }
                .padding(.bottom, ManiSpacing.lg)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
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

// MARK: - Subviews

// NOTE: kept (unmigrated) because CashflowView.swift still uses it;
// out of scope for this pass, which only covers SaleListView/POSView.
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

private struct SaleCardRowView: View {
    @Environment(\.maniTheme) private var theme
    let sale: Sale

    private var statusKind: ManiStatusKind {
        switch sale.status {
        case "Completed", "Paid": .success
        case "Due": .warning
        case "Cancelled": .error
        default: .neutral
        }
    }

    var body: some View {
        ManiCard {
            VStack(alignment: .leading, spacing: ManiSpacing.md) {
                ManiListRow(
                    avatar: ManiAvatar(initials: initials),
                    title: sale.customerName.isEmpty ? "Unknown" : sale.customerName,
                    subtitle: sale.customerPhone.isEmpty ? sale.timestamp.formatted(date: .abbreviated, time: .shortened) : sale.customerPhone,
                    value: sale.netPayable.string,
                    status: (sale.status, statusKind)
                )

                Divider().overlay(theme.base.border)

                HStack {
                    ManiBreakdownRow(label: "Sub Total", value: sale.subtotal.string)
                    Spacer()
                    ManiBreakdownRow(label: "Discount", value: sale.overallDiscountAmount.string)
                }
            }
        }
        .padding(.horizontal, ManiSpacing.lg)
    }

    private var initials: String {
        let trimmed = sale.customerName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(1)).uppercased()
    }
}
