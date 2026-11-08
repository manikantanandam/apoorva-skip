//
//  UPIQRView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// Placeholder UPI payment screen — there's no real payment gateway integration yet,
/// so this just shows a static QR and lets staff confirm the sale by hand once the
/// customer says they've paid.
public struct UPIQRView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CheckoutViewModel
    private let onConfirmed: (Sale) -> Void

    public init(viewModel: CheckoutViewModel, onConfirmed: @escaping (Sale) -> Void) {
        self.viewModel = viewModel
        self.onConfirmed = onConfirmed
    }

    public var body: some View {
        VStack(spacing: ManiSpacing.lg) {
            Spacer()

            ManiCard {
                VStack(spacing: ManiSpacing.md) {
                    ManiSwiftUIComponents.IconView(.qrCode, size: 160, color: theme.base.text)
                    ManiBreakdownRow(label: "Amount", value: "₹\(viewModel.finalTotal.moneyString)", emphasis: .total)
                }
                .frame(maxWidth: .infinity)
            }

            ManiNote("UPI payments are coming soon — this is a placeholder. Confirm once the customer has paid.", kind: .info)

            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
            }

            Spacer()

            ManiButton(
                "Mark as paid",
                isLoading: viewModel.isProcessing,
                action: {
                    Task {
                        if let sale = await viewModel.confirmSale() {
                            onConfirmed(sale)
                        }
                    }
                }
            )
        }
        .padding(ManiSpacing.lg)
        .background(theme.base.background.ignoresSafeArea())
        .navigationTitle("UPI Payment")
        .navigationBarTitleDisplayMode(.inline)
    }
}
