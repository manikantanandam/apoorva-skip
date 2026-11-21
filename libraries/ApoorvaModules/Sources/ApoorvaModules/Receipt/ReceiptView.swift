//
//  ReceiptView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// Bill saved (design 45): amount, how it was paid, and send receipt.
public struct ReceiptView: View {
    @Environment(\.maniTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: ReceiptViewModel
    /// `true` when reached straight from checkout (fresh sale, no back/swipe — "Done"
    /// closes the whole New Bill flow); `false` when viewed from sale history (normal back).
    private let cameFromCheckout: Bool
    private let onEditSale: (Sale) -> Void
    private let onDone: () -> Void
    private let onNewBill: (() -> Void)?
    private let onPreview: ((Sale) -> Void)?

    public init(
        viewModel: ReceiptViewModel,
        cameFromCheckout: Bool,
        onEditSale: @escaping (Sale) -> Void,
        onDone: @escaping () -> Void,
        onNewBill: (() -> Void)? = nil,
        onPreview: ((Sale) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.cameFromCheckout = cameFromCheckout
        self.onEditSale = onEditSale
        self.onDone = onDone
        self.onNewBill = onNewBill
        self.onPreview = onPreview
    }

    public var body: some View {
        Group {
            if let sale = viewModel.sale {
                content(for: sale)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.base.background.ignoresSafeArea())
            }
        }
        .navigationTitle(cameFromCheckout ? "" : "Receipt")
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

    private func summary(for sale: Sale) -> [ManiKeyValue] {
        var rows = [ManiKeyValue("Items", "\(sale.items.reduce(0) { $0 + $1.qty })"),
                    ManiKeyValue("Paid by", viewModel.paidBy)]
        if sale.overallDiscountAmount > 0 { rows.append(ManiKeyValue("Discount", "−" + Money.format(sale.overallDiscountAmount))) }
        if sale.isDue { rows.append(ManiKeyValue("Due on account", Money.format(sale.dueAmount))) }
        if viewModel.changeReturned > 0 { rows.append(ManiKeyValue("Change returned", Money.format(viewModel.changeReturned))) }
        return rows
    }

    @ViewBuilder private func content(for sale: Sale) -> some View {
        ScreenScroll {
            ManiHeroAmount(Money.format(sale.netPayable),
                           caption: "\(sale.isReturn ? "Return" : "Bill") \(sale.displayNumber) \(sale.isCancelled ? "cancelled" : "saved") · \(sale.customerName)",
                           icon: sale.isCancelled ? .warning : .checkCircle,
                           tint: sale.isCancelled ? theme.base.error : theme.base.success)
            ManiKeyValueSummary(rows: summary(for: sale), emphasizeLast: false)

            SectionHeader(title: "Send receipt")
            FlowLayout {
                if let url = viewModel.whatsAppURL {
                    ManiChip("WhatsApp", icon: .message) { openURL(url) }
                }
                ShareLink(item: viewModel.shareText) {
                    ManiStatusBadge("Share", kind: .neutral)
                }
                if let onPreview {
                    ManiChip("Print", icon: .printer) { onPreview(sale) }
                }
                if let url = viewModel.smsURL {
                    ManiChip("SMS", icon: .phone) { openURL(url) }
                }
            }

            SectionHeader(title: "Items")
            RowsCard {
                ForEach(sale.items) { item in
                    ManiListRow(title: item.categoryName,
                                subtitle: "\(Money.format(item.finalPrice)) × \(item.qty)\(item.doneByName.map { " · \($0)" } ?? "")",
                                value: Money.format(item.totalAmount))
                }
            }
            if !cameFromCheckout && !sale.isCancelled {
                ManiButton("Edit bill", icon: .edit, kind: .outline) { onEditSale(sale) }
                    .accessibilityIdentifier(AccessibilityID.Receipt.editBill)
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                if cameFromCheckout {
                    if let onNewBill {
                        ManiButton("New bill", icon: .plus, action: onNewBill)
                            .accessibilityIdentifier(AccessibilityID.Receipt.newBill)
                    }
                    ManiButton("Back to home", kind: .outline, action: onDone)
                        .accessibilityIdentifier(AccessibilityID.Receipt.home)
                }
            }
        }
    }
}

/// Printed receipt preview (design 46). There's no printer driver yet, so Print explains and Share sends the text.
public struct ReceiptPreviewView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: ReceiptViewModel
    private let printerName: String?
    @State private var isShowingPrinterNote = false

    public init(viewModel: ReceiptViewModel, printerName: String? = nil) {
        self.viewModel = viewModel
        self.printerName = printerName
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "58 mm thermal · \(printerName ?? "No printer paired")")
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(viewModel.thermalLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(ManiSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            if isShowingPrinterNote {
                ManiNote("Bluetooth printing is coming soon. Share the receipt for now, or print from another app.", kind: .info)
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Print", icon: .printer) { isShowingPrinterNote = true }
                ShareLink(item: viewModel.thermalLines.joined(separator: "\n")) {
                    Text("Share receipt")
                        .font(theme.typography.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: ManiTouchTarget.minimum)
                        .foregroundStyle(theme.accent.accent)
                }
            }
        }
        .navigationTitle("Receipt preview")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
