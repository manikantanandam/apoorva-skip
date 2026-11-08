//
//  SelectedCartItemsView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaModels
import SwiftUI
import ManiSwiftUIComponents

struct SelectedCartItemsView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable var viewModel: POSViewModel
    let onEditItem: (Int, CartItem) -> Void

    var body: some View {
        if viewModel.cart.items.isEmpty {
            VStack(spacing: ManiSpacing.sm) {
                ManiSwiftUIComponents.IconView(.cart, size: 32, color: theme.base.textSecondary)
                Text("Your cart is empty")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.base.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ManiSpacing.xl)
        } else {
            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                HStack(spacing: ManiSpacing.sm) {
                    Text("CURRENT CART")
                        .font(theme.typography.sectionHeader)
                        .foregroundStyle(theme.base.textSecondary)
                    ManiStatusBadge("\(viewModel.cart.totalItemsCount)", kind: .neutral)
                }
                .padding(.leading, ManiSpacing.xs)

                LazyVStack(spacing: ManiSpacing.sm) {
                    ForEach(Array(viewModel.cart.items.enumerated()), id: \.element.id) { index, item in
                        ManiCartLineRow(
                            title: item.category.name,
                            subtitle: "₹\(item.mrp.moneyString)/unit · \(item.discountPercent.moneyString)% off",
                            totalText: "₹\(item.totalItemsPrice.moneyString)",
                            quantityUnitText: "\(item.quantity) × ₹\(item.finalPrice.moneyString)",
                            onTap: { onEditItem(index, item) },
                            onRemove: { viewModel.remove(at: index) }
                        )
                    }
                }

                ManiBreakdownRow(label: "Items", value: "\(viewModel.cart.totalItemsCount)", emphasis: .total)
                    .padding(.horizontal, ManiSpacing.xs)
            }
        }
    }
}
