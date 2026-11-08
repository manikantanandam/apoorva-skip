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
    let onSelectCategory: (InventoryItem) -> Void

    @State private var isShowingCategoryPicker = false

    public init(viewModel: POSViewModel, spacing: CGFloat = ManiSpacing.sm, onSelectCategory: @escaping (InventoryItem) -> Void) {
        self.viewModel = viewModel
        self.spacing = spacing
        self.onSelectCategory = onSelectCategory
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ManiSpacing.md) {
            Text("QUICK ITEMS")
                .font(theme.typography.sectionHeader)
                .foregroundStyle(theme.base.textSecondary)
                .padding(.leading, ManiSpacing.xs)

            ManiButton("FIND", icon: .search, kind: .outline) {
                isShowingCategoryPicker = true
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: spacing)], spacing: spacing) {
                ForEach(viewModel.hotkeyItems) { item in
                    ManiCategoryTile(title: item.name, isHotkey: item.isHotkey) {
                        onSelectCategory(item)
                    }
                }
            }
        }
        .padding(ManiSpacing.lg)
        .background(theme.base.background)
        .sheet(isPresented: $isShowingCategoryPicker) {
            CategoryPickerSheet(categories: viewModel.allCategories) { item in
                isShowingCategoryPicker = false
                onSelectCategory(item)
            }
        }
    }
}

/// Mirrors the Flutter app's full-category bottom sheet opened from the "FIND" tile —
/// kept local to POS (not a coordinator route) since it's a search-and-pick overlay on
/// the same screen, not a navigation push.
private struct CategoryPickerSheet: View {
    @Environment(\.maniTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let categories: [InventoryItem]
    let onSelect: (InventoryItem) -> Void
    @State private var searchText = ""

    private var filteredCategories: [InventoryItem] {
        guard !searchText.isEmpty else { return categories }
        return categories.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: ManiSpacing.md) {
                ManiSearchField(text: $searchText, placeholder: "Search categories")
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.md)

                ScrollView {
                    if filteredCategories.isEmpty {
                        ManiNote("No categories found.", kind: .warning)
                            .padding(.horizontal, ManiSpacing.lg)
                            .padding(.top, ManiSpacing.lg)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: ManiSpacing.sm)], spacing: ManiSpacing.sm) {
                            ForEach(filteredCategories) { item in
                                ManiCategoryTile(title: item.name, isHotkey: item.isHotkey) {
                                    onSelect(item)
                                }
                            }
                        }
                        .padding(.horizontal, ManiSpacing.lg)
                        .padding(.bottom, ManiSpacing.lg)
                    }
                }
            }
            .background(theme.base.background.ignoresSafeArea())
            .navigationTitle("All Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
