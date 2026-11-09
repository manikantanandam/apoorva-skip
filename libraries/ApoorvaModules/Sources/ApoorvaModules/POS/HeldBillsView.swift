//
//  HeldBillsView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// Held bills: park and resume (design 51).
public struct HeldBillsView: View {
    @Bindable private var viewModel: HeldBillsViewModel
    private let onResume: (HeldBill) -> Void

    public init(viewModel: HeldBillsViewModel, onResume: @escaping (HeldBill) -> Void) {
        self.viewModel = viewModel
        self.onResume = onResume
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(viewModel.heldBills.count) parked · auto-clears at day close")
            if viewModel.heldBills.isEmpty {
                ManiEmptyState(icon: .pause, title: "No held bills",
                               message: "Hold a bill from checkout to serve the next customer, then resume it here.")
            } else {
                RowsCard {
                    ForEach(viewModel.heldBills) { bill in
                        ManiListRow(title: bill.customerName.isEmpty ? "Walk-in" : bill.customerName,
                                    subtitle: "\(bill.items.count) items · \(bill.createdAt.timeOnly)",
                                    value: Money.format(bill.total),
                                    status: ("Held", .warning)) { onResume(bill) }
                            .contextMenu {
                                Button("Discard", role: .destructive) { Task { await viewModel.delete(bill) } }
                            }
                    }
                }
                ManiNote("Tap a bill to resume. Long-press to discard.", kind: .info)
            }
        }
        .navigationTitle("Held bills")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.prepareData() }
    }
}
