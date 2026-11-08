//
//  ItemPriceCalculatorView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct ItemPriceCalculatorView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: ItemPriceCalculatorViewModel
    private let onSave: (CartItem) -> Void

    public init(viewModel: ItemPriceCalculatorViewModel, onSave: @escaping (CartItem) -> Void) {
        self.viewModel = viewModel
        self.onSave = onSave
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: ManiSpacing.lg) {
                ManiInputField(
                    label: "MRP (per unit)",
                    text: $viewModel.mrpText,
                    placeholder: "e.g. 120",
                    keyboard: .decimal
                )

                HStack {
                    Text("Quantity")
                        .font(theme.typography.secondary)
                        .foregroundStyle(theme.base.textSecondary)
                    Spacer()
                    HStack(spacing: ManiSpacing.md) {
                        Button(action: viewModel.decrement) {
                            ManiSwiftUIComponents.IconView(.minus, size: 14, color: theme.accent.accent)
                        }
                        Text("\(viewModel.quantity)")
                            .font(theme.typography.body.weight(.semibold))
                            .monospacedDigit()
                            .frame(minWidth: 24)
                        Button(action: viewModel.increment) {
                            ManiSwiftUIComponents.IconView(.plus, size: 14, color: theme.accent.accent)
                        }
                    }
                    .buttonStyle(.plain)
                }

                ManiSegmentedControl(
                    selection: $viewModel.discountType,
                    options: [
                        (value: DiscountType.percentage, title: "% Off"),
                        (value: DiscountType.amount, title: "₹ Discount"),
                        (value: DiscountType.finalPrice, title: "Final ₹")
                    ]
                )

                ManiInputField(
                    label: dynamicInputLabel,
                    text: $viewModel.dynamicInputText,
                    placeholder: "0",
                    keyboard: .decimal
                )

                if viewModel.discountType == .percentage {
                    HStack(spacing: ManiSpacing.sm) {
                        ForEach([0.0, 5.0, 10.0, 15.0, 20.0], id: \.self) { percent in
                            ManiChip(
                                "\(Int(percent))%",
                                isSelected: viewModel.dynamicInputText == percent.moneyString,
                                action: { viewModel.applyQuickPercent(percent) }
                            )
                        }
                    }
                }

                ManiCard {
                    VStack(spacing: ManiSpacing.sm) {
                        ManiBreakdownRow(label: "Gross Total", value: "₹\(viewModel.grossTotal.moneyString)")
                        ManiBreakdownRow(label: "Discount", value: "-₹\(viewModel.discountAmount.moneyString)")
                        ManiBreakdownRow(label: "Net Payable", value: "₹\(viewModel.netPayable.moneyString)", emphasis: .total)
                    }
                }

                ManiButton(
                    viewModel.isEditMode ? "UPDATE ITEM" : "ADD TO BILL",
                    isEnabled: viewModel.isValid,
                    action: { onSave(viewModel.buildCartItem()) }
                )
            }
            .padding(ManiSpacing.lg)
        }
        .background(theme.base.background.ignoresSafeArea())
        .navigationTitle(viewModel.category.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dynamicInputLabel: String {
        switch viewModel.discountType {
        case .percentage: "Discount %"
        case .amount: "Discount amount (₹)"
        case .finalPrice: "Final price per unit (₹)"
        }
    }
}
