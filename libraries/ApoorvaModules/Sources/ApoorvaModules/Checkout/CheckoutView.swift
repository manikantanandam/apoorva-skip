//
//  CheckoutView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// Checkout (design 42): customer, totals, payment mode.
public struct CheckoutView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CheckoutViewModel
    private let customerSubtitle: String?
    private let onChangeCustomer: () -> Void
    private let onSplit: () -> Void
    private let onRequireUPIConfirmation: () -> Void
    private let onHold: (() -> Void)?
    private let onConfirmed: (Sale) -> Void

    public init(
        viewModel: CheckoutViewModel,
        customerSubtitle: String? = nil,
        onChangeCustomer: @escaping () -> Void = {},
        onSplit: @escaping () -> Void = {},
        onRequireUPIConfirmation: @escaping () -> Void,
        onHold: (() -> Void)? = nil,
        onConfirmed: @escaping (Sale) -> Void
    ) {
        self.viewModel = viewModel
        self.customerSubtitle = customerSubtitle
        self.onChangeCustomer = onChangeCustomer
        self.onSplit = onSplit
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
        rows.append(ManiKeyValue("Round off", String(format: "₹%.2f", -viewModel.roundOff)))
        rows.append(ManiKeyValue("Total", Money.format(viewModel.finalTotal)))
        return rows
    }

    public var body: some View {
        ScreenScroll {
            RowsCard {
                ManiListRow(avatar: ManiAvatar(initials: String(customerTitle.prefix(1))),
                            title: customerTitle,
                            subtitle: customerSubtitle ?? (viewModel.cart.customerPhone ?? "Tap to attach a customer"),
                            value: "Change",
                            action: onChangeCustomer)
            }

            ManiKeyValueSummary(rows: summaryRows)

            SectionHeader(title: "Payment")
            FlowLayout {
                ForEach(viewModel.enabledModes, id: \.self) { mode in
                    ManiChip(mode.rawValue, isSelected: viewModel.mode == mode) {
                        viewModel.mode = mode
                        if mode == .split { onSplit() }
                    }
                }
            }

            if viewModel.mode == .cash {
                ManiInputField(label: "Cash received (optional)", text: $viewModel.cashReceivedText,
                               placeholder: Money.format(viewModel.finalTotal), keyboard: .decimal)
                if viewModel.changeDue > 0 {
                    ManiBreakdownRow(label: "Change to return", value: Money.format(viewModel.changeDue), emphasis: .total)
                }
            }
            if viewModel.mode == .split {
                ManiNote("Split: \(Money.format(viewModel.splitPaid)) entered, \(Money.format(viewModel.splitRemaining)) left.",
                         kind: .info)
            }
            if viewModel.creditNeedsCustomer {
                ManiNote("Credit needs a customer, so the due lands on their account.", kind: .warning)
            }
            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton(viewModel.mode == .split && !viewModel.isSettled ? "Finish split" : "Collect \(Money.format(viewModel.finalTotal))",
                           isLoading: viewModel.isProcessing,
                           isEnabled: !viewModel.creditNeedsCustomer,
                           action: handleConfirmTapped)
                if let onHold {
                    ManiButton("Hold bill", kind: .outline, action: onHold)
                }
            }
        }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleConfirmTapped() {
        if viewModel.mode == .split && !viewModel.isSettled {
            onSplit()
            return
        }
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

/// Split payment across modes (design 43).
public struct SplitPaymentView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CheckoutViewModel
    private let onConfirmed: (Sale) -> Void

    public init(viewModel: CheckoutViewModel, onConfirmed: @escaping (Sale) -> Void) {
        self.viewModel = viewModel
        self.onConfirmed = onConfirmed
    }

    private let modes: [PaymentMode] = [.cash, .upi, .card, .credit]

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Total \(Money.format(viewModel.finalTotal))")
            if viewModel.splitPaid > 0 {
                ManiSplitBarCard(title: "Split", caption: nil,
                                 segments: modes.compactMap { mode in
                                     viewModel.splitAmounts[mode].map { ManiSplitSegment(mode.title, $0) }
                                 })
            }
            RowsCard {
                ForEach(modes.filter { viewModel.splitAmounts[$0] != nil }, id: \.self) { mode in
                    ManiListRow(title: mode.title, subtitle: "Tap to clear",
                                value: Money.format(viewModel.splitAmounts[mode] ?? 0),
                                status: ("Paid", .success)) { viewModel.clearSplit(mode) }
                }
                ManiListRow(title: viewModel.splitEntryMode.title, subtitle: "Remaining",
                            value: Money.format(viewModel.splitRemaining), status: ("Pending", .warning))
            }
            ManiSegmentedControl(selection: $viewModel.splitEntryMode,
                                 options: modes.map { ($0, $0.title) })
            ManiHeroAmount(viewModel.splitEntryText.isEmpty ? Money.format(viewModel.splitRemaining) : "₹" + viewModel.splitEntryText,
                           caption: "by \(viewModel.splitEntryMode.title.lowercased())")
            ManiKeypad { key in
                switch key {
                case .digit(let value): viewModel.splitKey("\(value)")
                case .decimal: viewModel.splitKey(".")
                case .backspace: viewModel.splitKey("⌫")
                }
            }
            if viewModel.creditNeedsCustomer {
                ManiNote("Credit needs a customer on the bill.", kind: .warning)
            }
            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
            }
        } bottom: {
            if viewModel.isSettled {
                ManiButton("Confirm \(Money.format(viewModel.finalTotal))", isLoading: viewModel.isProcessing) {
                    Task { if let sale = await viewModel.confirmSale() { onConfirmed(sale) } }
                }
            } else {
                let entry = Double(viewModel.splitEntryText) ?? viewModel.splitRemaining
                ManiButton("Add \(Money.format(min(entry, viewModel.splitRemaining))) by \(viewModel.splitEntryMode.title.lowercased())",
                           isEnabled: viewModel.splitRemaining > 0) {
                    viewModel.confirmSplitEntry()
                }
            }
        }
        .navigationTitle("Split payment")
        .navigationBarTitleDisplayMode(.inline)
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
