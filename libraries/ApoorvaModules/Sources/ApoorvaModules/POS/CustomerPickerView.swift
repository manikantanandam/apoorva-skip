//
//  CustomerPickerView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct CustomerPickerView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CustomerPickerViewModel
    private let onSelect: (Customer?) -> Void

    public init(viewModel: CustomerPickerViewModel, onSelect: @escaping (Customer?) -> Void) {
        self.viewModel = viewModel
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(spacing: ManiSpacing.md) {
            ManiSearchField(text: $viewModel.searchText, placeholder: "Search by name or phone")
                .padding(.horizontal, ManiSpacing.lg)
                .padding(.top, ManiSpacing.md)

            ScrollView {
                LazyVStack(spacing: ManiSpacing.sm) {
                    if viewModel.filteredCustomers.isEmpty {
                        ManiNote("No customers found.", kind: .warning)
                            .padding(.top, ManiSpacing.lg)
                    } else {
                        ForEach(viewModel.filteredCustomers) { customer in
                            ManiListRow(
                                avatar: ManiAvatar(initials: initials(for: customer.name)),
                                title: customer.name,
                                subtitle: customer.phone,
                                action: { onSelect(customer) }
                            )
                        }
                    }
                }
                .padding(.horizontal, ManiSpacing.lg)
            }

            ManiButton("Continue as walk-in", kind: .outline, action: { onSelect(nil) })
                .padding(.horizontal, ManiSpacing.lg)
                .padding(.bottom, ManiSpacing.lg)
        }
        .background(theme.base.background.ignoresSafeArea())
        .navigationTitle("Select Customer")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.prepareData()
        }
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }
}
