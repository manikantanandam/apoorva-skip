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
    let items: [InventoryItem]
    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(items, id: \.self.id) { item in
                ManiListRow(title: item.name)
            }
        }
    }
}
