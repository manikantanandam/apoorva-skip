//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI

struct GridView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let rowCount: Int // The variable "m" (number of rows per column)
    let spacing: CGFloat
    let content: (Item) -> Content
    
    // Split the flat array into a 2D column array dynamically
    private var columnsData: [[Item]] {
        guard rowCount > 0 else { return [] }
        return stride(from: 0, to: items.count, by: rowCount).map { startIndex in
            let endIndex = min(startIndex + rowCount, items.count)
            return Array(items[startIndex..<endIndex])
        }
    }
    
    init(
        items: [Item],
        rowCount: Int,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.rowCount = rowCount
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: spacing) {
                // Outer loop renders the calculated number of columns (n)
                ForEach(0..<columnsData.count, id: \.self) { columnIndex in
                    VStack(spacing: spacing) {
                        // Inner loop renders the configured number of rows (m)
                        ForEach(columnsData[columnIndex]) { item in
                            content(item)
                        }
                    }
                }
            }
            .padding(.vertical, 4) // Prevents card shadows from being clipped
        }
    }
}
