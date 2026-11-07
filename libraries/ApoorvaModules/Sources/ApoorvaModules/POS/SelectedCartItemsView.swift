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

    var body: some View {
        if !viewModel.cartItems.isEmpty {
            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                Text("CART")
                    .font(theme.typography.sectionHeader)
                    .foregroundStyle(theme.base.textSecondary)
                    .padding(.leading, ManiSpacing.xs)

                LazyVStack(spacing: 0) {
                    ForEach(viewModel.cartItems, id: \.self.id) { item in
                        ManiListRow(title: item.name, value: "x\(viewModel.quantity(for: item))")
                    }
                }

                ManiBreakdownRow(label: "Items", value: "\(viewModel.cartItemCount)", emphasis: .total)
                    .padding(.horizontal, ManiSpacing.xs)
            }
        }
    }
}
