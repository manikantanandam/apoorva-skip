//
//  SelectedCartItemsView.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import ApoorvaModels
import SwiftUI

struct SelectedCartItemsView: View {
    let items: [Category]
    var body: some View {
        LazyVStack {
            ForEach(items, id: \.self.id) { item in
                Text(item.name)
            }
        }
    }
}
