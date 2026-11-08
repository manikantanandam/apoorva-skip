//
//  HeldBillsView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct HeldBillsView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: HeldBillsViewModel
    private let onResume: (HeldBill) -> Void

    public init(viewModel: HeldBillsViewModel, onResume: @escaping (HeldBill) -> Void) {
        self.viewModel = viewModel
        self.onResume = onResume
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: ManiSpacing.sm) {
                if viewModel.heldBills.isEmpty {
                    ManiNote("No bills on hold.", kind: .info)
                        .padding(.top, ManiSpacing.lg)
                } else {
                    ForEach(viewModel.heldBills) { bill in
                        ManiCard {
                            HStack(spacing: ManiSpacing.md) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bill.customerName.isEmpty ? "Walk-in customer" : bill.customerName)
                                        .font(theme.typography.body.weight(.medium))
                                        .foregroundStyle(theme.base.text)
                                    Text("\(bill.items.count) items · ₹\(bill.total.moneyString)")
                                        .font(theme.typography.secondary)
                                        .foregroundStyle(theme.base.textSecondary)
                                }
                                Spacer()
                                ManiButton("Resume", icon: .check, kind: .outline, action: { onResume(bill) })
                                    .frame(width: 120)
                            }
                        }
                    }
                }
            }
            .padding(ManiSpacing.lg)
        }
        .background(theme.base.background.ignoresSafeArea())
        .navigationTitle("Held Bills")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.prepareData()
        }
    }
}
