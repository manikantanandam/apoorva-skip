//
//  ReceiptView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct ReceiptView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: ReceiptViewModel
    /// `true` when reached straight from checkout (fresh sale, no back/swipe — "Done"
    /// closes the whole New Bill flow); `false` when viewed from sale history (normal back).
    private let cameFromCheckout: Bool
    private let onEditSale: (Sale) -> Void
    private let onDone: () -> Void

    public init(
        viewModel: ReceiptViewModel,
        cameFromCheckout: Bool,
        onEditSale: @escaping (Sale) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.cameFromCheckout = cameFromCheckout
        self.onEditSale = onEditSale
        self.onDone = onDone
    }

    public var body: some View {
        ScrollView {
            if let sale = viewModel.sale {
                content(for: sale)
            } else {
                ProgressView()
                    .padding(.top, ManiSpacing.xl)
            }
        }
        .background(theme.base.background.ignoresSafeArea())
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(cameFromCheckout)
        .toolbar {
            if cameFromCheckout {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder private func content(for sale: Sale) -> some View {
        VStack(spacing: ManiSpacing.lg) {
            VStack(spacing: ManiSpacing.sm) {
                ManiSwiftUIComponents.IconView(.checkCircle, size: 56, color: theme.base.success)
                Text("Sale Successful!")
                    .font(theme.typography.body.weight(.bold))
                    .foregroundStyle(theme.base.text)
                Text("Sale #\(sale.id.prefix(8))")
                    .font(theme.typography.secondary)
                    .foregroundStyle(theme.base.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, ManiSpacing.lg)

            ManiCard {
                VStack(spacing: 0) {
                    ForEach(sale.items) { item in
                        VStack(spacing: 2) {
                            ManiListRow(
                                title: item.categoryName,
                                subtitle: "₹\(item.stickerPrice.moneyString) × \(item.qty)",
                                value: "₹\(item.totalAmount.moneyString)"
                            )
                            if item.unitDiscountAmount > 0 {
                                Text("Saved ₹\(item.unitDiscountAmount.moneyString)/unit")
                                    .font(theme.typography.secondary)
                                    .foregroundStyle(theme.base.success)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }

            ManiCard {
                VStack(spacing: ManiSpacing.sm) {
                    ManiBreakdownRow(label: "Total MRP", value: "₹\(sale.totalMRP.moneyString)")
                    ManiBreakdownRow(label: "Item Discounts", value: "-₹\(sale.totalItemsDiscount.moneyString)")
                    ManiBreakdownRow(label: "Subtotal", value: "₹\(sale.subTotal.moneyString)")
                    ManiBreakdownRow(label: "Additional Discount", value: "-₹\(sale.overallDiscountAmount.moneyString)")
                    ManiBreakdownRow(label: "Bill Amount", value: "₹\(sale.billAmount.moneyString)")
                    ManiBreakdownRow(label: "Round-off", value: "-₹\(sale.roundOff.moneyString)")
                    ManiBreakdownRow(label: "Net Payment", value: "₹\(sale.netPayable.moneyString)", emphasis: .total)
                    if sale.totalSavings > 0 {
                        ManiStatusBadge("YOU SAVED ₹\(sale.totalSavings.moneyString)", kind: .success)
                    }
                }
            }

            ManiCard {
                VStack(spacing: ManiSpacing.sm) {
                    ForEach(Array(sale.payments.filter { $0.value > 0 }), id: \.key) { mode, amount in
                        ManiBreakdownRow(label: paymentTitle(mode), value: "₹\(amount.moneyString)")
                    }
                }
            }

            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Print Receipt", icon: .printer, kind: .outline, isEnabled: false, action: {})
                ManiButton("Send Text Message", kind: .outline, isEnabled: false, action: {})
                ManiButton("Share WhatsApp", icon: .share, kind: .outline, isEnabled: false, action: {})
                ManiButton("Edit Sale / Modify Items", action: { onEditSale(sale) })
            }
        }
        .padding(ManiSpacing.lg)
    }

    private func paymentTitle(_ mode: PaymentMode) -> String {
        switch mode {
        case .cash: "Cash"
        case .upi: "UPI"
        case .card: "Card"
        case .credit: "Credit"
        }
    }
}
