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
    // 1. Flattened data list (Supports infinite items)
    let items: [ApoorvaModels.InventoryItem]
    let rowCount: Int
    let cardHeight: CGFloat
    let spacing: CGFloat

    public init(items: [ApoorvaModels.InventoryItem],
                rowCount: Int = 2,
                cardHeight: CGFloat = 85,
                spacing: CGFloat = 4) {
        self.items = items
        self.rowCount = rowCount
        self.cardHeight = cardHeight
        self.spacing = spacing
    }

    private var calculatedActionCardHeight: CGFloat {
        let totalCardHeight = CGFloat(rowCount) * cardHeight
        let totalSpacingHeight = CGFloat(rowCount - 1) * spacing
        return totalCardHeight + totalSpacingHeight
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Title Label
            Text("QUICK ITEMS")
                .font(theme.typography.sectionHeader)
                .foregroundStyle(theme.base.textSecondary)
                .padding(.leading, 4)

            HStack(alignment: .top, spacing: spacing) {

                GridView(items: items, rowCount: rowCount, spacing: 4) { item in

                    // Inject whatever look and structural treatments you prefer here:
                    QuickItemCard(
                        title: item.name,
                        height: 85, width: 85
                    )
                        .onTapGesture {
                        }

                }
                // NOTE: kept as CustomButton — ManiButton v1 has no
                // vertical icon-above-text layout with a caller-supplied
                // minHeight, which this compact "FIND" tile needs.
                CustomButton(text: "FIND",
                             icon: .search,
                             minHeight: calculatedActionCardHeight,
                             backgroundColor: .buttonBackground,
                             alignment: .vertical) {
                    print("Find tapped")
                }
                .frame(maxWidth: 90)
            }
        }
        .padding(16)
        .background(theme.base.background)
    }
}




struct QuickItemCard: View {
    @Environment(\.maniTheme) private var theme
    let title: String
    let height: CGFloat
    let width: CGFloat

    var body: some View {
        ManiCard {
            Text(title)
                .font(theme.typography.body.weight(.medium))
                .foregroundStyle(theme.base.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .top) {
            theme.accent.accent
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.card, style: .continuous))
        }
    }
}
