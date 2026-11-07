//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 07/10/26.
//

import SwiftUI
import ManiSwiftUIComponents

public struct POSView: View {

    // 1. Inject the ViewModel
    @Bindable private var viewModel: POSViewModel

    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ManiSpacing.md) {
                    ManiInputField(
                        label: "Customer name",
                        text: $viewModel.customerName,
                        placeholder: "e.g. Priya"
                    )

                    ManiInputField(
                        label: "Phone number",
                        text: $viewModel.customerPhoneNumber,
                        placeholder: "e.g. 98765 43210",
                        keyboard: .phone
                    )

                    QuickItemsView(viewModel: viewModel)

                    SelectedCartItemsView(viewModel: viewModel)

                    Spacer()
                }
                .padding(ManiSpacing.lg)
            }
            .safeAreaInset(edge: .bottom) {
                if viewModel.cartItemCount > 0 {
                    ManiActionBar(
                        summaryText: "\(viewModel.cartItemCount) items",
                        primaryTitle: "Collect",
                        primaryAction: { print("Collect tapped") },
                        secondaryTitle: "Hold bill",
                        secondaryAction: { print("Hold bill tapped") }
                    )
                    .padding(.horizontal, ManiSpacing.lg)
                }
            }
        }
    }
}
