//
//  CheckoutView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct CheckoutView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CheckoutViewModel
    private let onRequireUPIConfirmation: () -> Void
    private let onConfirmed: (Sale) -> Void

    public init(
        viewModel: CheckoutViewModel,
        onRequireUPIConfirmation: @escaping () -> Void,
        onConfirmed: @escaping (Sale) -> Void
    ) {
        self.viewModel = viewModel
        self.onRequireUPIConfirmation = onRequireUPIConfirmation
        self.onConfirmed = onConfirmed
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: ManiSpacing.lg) {
                ManiCard {
                    VStack(alignment: .leading, spacing: ManiSpacing.xs) {
                        Text(viewModel.cart.customerName?.isEmpty == false ? viewModel.cart.customerName! : "Walk-in Customer")
                            .font(theme.typography.body.weight(.medium))
                            .foregroundStyle(theme.base.text)
                        Text(viewModel.cart.customerPhone?.isEmpty == false ? viewModel.cart.customerPhone! : "No phone")
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.base.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                    Text("DISCOUNT")
                        .font(theme.typography.sectionHeader)
                        .foregroundStyle(theme.base.textSecondary)
                    HStack(spacing: ManiSpacing.sm) {
                        ForEach([0.0, 5.0, 10.0, 15.0, 20.0], id: \.self) { percent in
                            ManiChip(
                                "\(Int(percent))%",
                                isSelected: viewModel.overallDiscountPercent == percent,
                                action: { viewModel.setDiscount(percent) }
                            )
                        }
                    }
                }

                ManiCard {
                    VStack(spacing: ManiSpacing.sm) {
                        ManiBreakdownRow(label: "Total MRP", value: "₹\(viewModel.totalMRP.moneyString)")
                        ManiBreakdownRow(label: "Item Discounts", value: "-₹\(viewModel.itemDiscounts.moneyString)")
                        ManiBreakdownRow(label: "Subtotal", value: "₹\(viewModel.subtotal.moneyString)")
                        ManiBreakdownRow(label: "Additional Discount", value: "-₹\(viewModel.overallDiscountAmount.moneyString)")
                        ManiInputField(label: "Round off (₹)", text: $viewModel.roundOffText, keyboard: .decimal)
                        ManiBreakdownRow(label: "NET TOTAL", value: "₹\(viewModel.finalTotal.moneyString)", emphasis: .total)
                    }
                }

                VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                    Text("PAYMENT METHODS")
                        .font(theme.typography.sectionHeader)
                        .foregroundStyle(theme.base.textSecondary)
                    ForEach(PaymentMode.allCases, id: \.self) { mode in
                        ManiPaymentModeRow(
                            title: title(for: mode),
                            icon: icon(for: mode),
                            isSelected: viewModel.selectedModes[mode] == true,
                            amountText: viewModel.amountBinding(for: mode),
                            onToggle: { isOn in viewModel.toggleMode(mode, isOn: isOn) }
                        )
                    }
                }

                balanceBar
            }
            .padding(ManiSpacing.lg)
        }
        .background(theme.base.background.ignoresSafeArea())
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var balanceBar: some View {
        VStack(spacing: ManiSpacing.sm) {
            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
            }
            ManiBreakdownRow(
                label: viewModel.isSettled ? "Settled" : "Due",
                value: "₹\(abs(viewModel.balance).moneyString)",
                emphasis: .total
            )
            ManiButton(
                "CONFIRM SALE",
                isLoading: viewModel.isProcessing,
                isEnabled: viewModel.isSettled,
                action: handleConfirmTapped
            )
        }
    }

    private func handleConfirmTapped() {
        if viewModel.requiresUPIConfirmation {
            onRequireUPIConfirmation()
            return
        }
        Task {
            if let sale = await viewModel.confirmSale() {
                onConfirmed(sale)
            }
        }
    }

    private func title(for mode: PaymentMode) -> String {
        switch mode {
        case .cash: "Cash"
        case .upi: "UPI"
        case .card: "Card"
        case .credit: "Credit"
        }
    }

    private func icon(for mode: PaymentMode) -> ManiIconName {
        switch mode {
        case .cash: .cash
        case .upi: .qrCode
        case .card: .card
        case .credit: .credit
        }
    }
}
