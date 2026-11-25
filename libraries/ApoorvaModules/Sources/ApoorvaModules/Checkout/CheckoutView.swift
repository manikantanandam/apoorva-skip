//
//  CheckoutView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// Checkout (design 42): customer, totals, and an amount box per payment mode (several = split).
public struct CheckoutView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CheckoutViewModel
    @State private var isAmountFocused = false
    private let customerSubtitle: String?
    private let onChangeCustomer: () -> Void
    private let onRequireUPIConfirmation: () -> Void
    private let onHold: (() -> Void)?
    private let onConfirmed: (Sale) -> Void

    public init(
        viewModel: CheckoutViewModel,
        customerSubtitle: String? = nil,
        onChangeCustomer: @escaping () -> Void = {},
        onRequireUPIConfirmation: @escaping () -> Void,
        onHold: (() -> Void)? = nil,
        onConfirmed: @escaping (Sale) -> Void
    ) {
        self.viewModel = viewModel
        self.customerSubtitle = customerSubtitle
        self.onChangeCustomer = onChangeCustomer
        self.onRequireUPIConfirmation = onRequireUPIConfirmation
        self.onHold = onHold
        self.onConfirmed = onConfirmed
    }

    private var customerTitle: String {
        viewModel.cart.customerName?.isEmpty == false ? viewModel.cart.customerName! : "Walk-in customer"
    }

    private var summaryRows: [ManiKeyValue] {
        var rows = [ManiKeyValue("Subtotal (\(viewModel.itemCount) items)", Money.format(viewModel.subtotal))]
        if viewModel.overallDiscountAmount > 0 {
            rows.append(ManiKeyValue("Discount", "−" + Money.format(viewModel.overallDiscountAmount)))
        }
        if abs(viewModel.roundOff) >= 0.005 {
            rows.append(ManiKeyValue("Round off", String(format: "₹%.2f", -viewModel.roundOff)))
        }
        rows.append(ManiKeyValue("Total", Money.format(viewModel.finalTotal)))
        return rows
    }

    /// Mode whose amount box is showing; falls back to the first enabled mode if the chosen one was switched off.
    private var activeMode: PaymentMode {
        viewModel.enabledModes.contains(viewModel.selectedMode) ? viewModel.selectedMode : (viewModel.enabledModes.first ?? .cash)
    }

    /// Chip title carries the amount already entered for that mode, so switching chips never hides it.
    private func chipTitle(_ mode: PaymentMode) -> String {
        guard let text = viewModel.amountTexts[mode], let amount = Double(text), amount > 0 else { return mode.title }
        return "\(mode.title) · \(Money.format(amount))"
    }

    private var amountPlaceholder: String {
        let nothingEntered = viewModel.amountTexts.values.allSatisfy { (Double($0) ?? 0) <= 0 }
        return Money.format(nothingEntered ? viewModel.finalTotal : viewModel.remaining)
    }

    public var body: some View {
        ScreenScroll {
            RowsCard {
                ManiListRow(avatar: ManiAvatar(initials: String(customerTitle.prefix(1))),
                            title: customerTitle,
                            subtitle: customerSubtitle ?? (viewModel.cart.customerPhone ?? "Tap to attach a customer"),
                            value: "Change",
                            action: onChangeCustomer)
                    .accessibilityIdentifier(AccessibilityID.Checkout.customerRow)
            }

            ManiKeyValueSummary(rows: summaryRows)

            SectionHeader(title: "Payment")
            FlowLayout {
                ForEach(viewModel.enabledModes, id: \.self) { mode in
                    ManiChip(chipTitle(mode), isSelected: activeMode == mode) {
                        viewModel.selectedMode = mode
                    }
                    .accessibilityIdentifier(AccessibilityID.Checkout.mode(mode.rawValue))
                }
            }
            ManiInputField(label: "\(activeMode.title) amount", text: amountBinding(activeMode),
                           placeholder: amountPlaceholder, keyboard: .default,
                           focus: $isAmountFocused, submitKind: .done,
                           onSubmit: { isAmountFocused = false })
                .accessibilityIdentifier(AccessibilityID.Checkout.cashReceived)

            VStack(spacing: ManiSpacing.sm) {
                ManiBreakdownRow(label: "Paid", value: Money.format(viewModel.paid))
                ManiBreakdownRow(label: viewModel.overpaid > 0 ? "Over by" : "Pending",
                                 value: Money.format(viewModel.overpaid > 0 ? viewModel.overpaid : viewModel.remaining),
                                 emphasis: .total)
                if viewModel.changeDue > 0 {
                    ManiBreakdownRow(label: "Change to return", value: Money.format(viewModel.changeDue))
                        .accessibilityIdentifier(AccessibilityID.Checkout.changeDue)
                }
            }
            if viewModel.creditNeedsCustomer {
                ManiNote("Credit needs a customer, so the due lands on their account.", kind: .warning)
                    .accessibilityIdentifier(AccessibilityID.Checkout.creditNote)
            }
            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
                    .accessibilityIdentifier(AccessibilityID.Checkout.error)
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Collect \(Money.format(viewModel.finalTotal))",
                           isLoading: viewModel.isProcessing,
                           isEnabled: viewModel.isSettled,
                           action: handleConfirmTapped)
                    .accessibilityIdentifier(AccessibilityID.Checkout.collect)
                if let onHold {
                    ManiButton("Hold bill", kind: .outline, action: onHold)
                        .accessibilityIdentifier(AccessibilityID.Checkout.hold)
                }
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.checkoutStarted() }
    }

    private func amountBinding(_ mode: PaymentMode) -> Binding<String> {
        Binding(get: { viewModel.amountTexts[mode] ?? "" },
                set: { viewModel.amountTexts[mode] = $0 })
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
}

extension PaymentMode {
    var title: String {
        switch self {
        case .cash: "Cash"
        case .upi: "UPI"
        case .card: "Card"
        case .credit: "Credit"
        }
    }
}
