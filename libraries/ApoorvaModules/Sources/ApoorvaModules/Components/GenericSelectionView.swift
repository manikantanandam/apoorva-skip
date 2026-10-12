//
//  GenericSelectionView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 11/10/26.
//

import SwiftUI

/// A generic list view that takes an array of Identifiable items and returns the selected item.
public struct GenericSelectionView<T: Identifiable, Content: View>: View {
    let items: [T]
    let onSelect: (T) -> Void
    let content: (T) -> Content
    
    public init(
        items: [T],
        onSelect: @escaping (T) -> Void,
        @ViewBuilder content: @escaping (T) -> Content
    ) {
        self.items = items
        self.onSelect = onSelect
        self.content = content
    }
    
    public var body: some View {
        List(items) { item in
            Button(action: {
                onSelect(item)
            }) {
                // Renders the custom view provided by the caller
                content(item)
            }
            // Ensures the entire row is tappable without standard button text coloring
            .buttonStyle(.plain)
        }
    }
}
