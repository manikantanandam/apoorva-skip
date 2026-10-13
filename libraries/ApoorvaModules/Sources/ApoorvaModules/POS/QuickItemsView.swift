//
//  QuickItemsView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI
import ApoorvaModels

public struct QuickItemsView: View {
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
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.3, green: 0.4, blue: 0.5))
                .padding(.leading, 4)
            
            HStack(alignment: .top, spacing: spacing) {
                
                GridView(items: items, rowCount: rowCount, spacing: 4) { item in
                    
                    // Inject whatever look and structural treatments you prefer here:
                    QuickItemCard(
                        title: item.name,
                        height: 85, width: 85
                    )
                        .onTapGesture {
                            print("Selected \(item.name)")
                        }
                    
                }
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
        .background(Color(red: 0.98, green: 0.96, blue: 0.96))
    }
}




struct QuickItemCard: View {
    let title: String
    let height: CGFloat
    let width: CGFloat

    
    var body: some View {
        CardView {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .default))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(width: width, height: height)
        .overlay(alignment: .top) {
            Color(.systemOrange)
                .frame(height: 6)
        }
    }
}
