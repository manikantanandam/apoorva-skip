//
//  QuickItemsView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct QuickItemsView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable var viewModel: POSViewModel
    let spacing: CGFloat

    public init(viewModel: POSViewModel, spacing: CGFloat = ManiSpacing.sm) {
        self.viewModel = viewModel
        self.spacing = spacing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.md) {
            // Header Title Label
            Text("QUICK ITEMS")
                .font(theme.typography.sectionHeader)
                .foregroundStyle(theme.base.textSecondary)
                .padding(.leading, ManiSpacing.xs)

            // NOTE: kept as CustomButton — ManiButton v1 has no vertical
            // icon-above-text layout with a caller-supplied minHeight,
            // which this compact "FIND" tile needs.
            CustomButton(text: "FIND",
                         icon: .search,
                         minHeight: 48,
                         backgroundColor: .buttonBackground,
                         alignment: .horizontal) {
                print("Find tapped")
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: spacing)], spacing: spacing) {
                ForEach(viewModel.items) { item in
                    // NOTE: `priceText` is a placeholder — `InventoryItem`
                    // has no price field yet, so there's no real value to show.
                    ManiItemTile(
                        title: item.name,
                        priceText: "—",
                        quantity: viewModel.quantity(for: item),
                        onIncrement: { viewModel.increment(item) },
                        onDecrement: { viewModel.decrement(item) }
                    )
                }
            }
        }
        .padding(ManiSpacing.lg)
        .background(theme.base.background)
    }
}
