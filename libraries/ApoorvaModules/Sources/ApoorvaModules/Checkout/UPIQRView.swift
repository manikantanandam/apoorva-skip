//
//  UPIQRView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents
#if canImport(CoreImage.CIFilterBuiltins)
import CoreImage.CIFilterBuiltins
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Pay by UPI (design 44): a real `upi://pay` QR for the bill amount. There's no gateway,
/// so staff confirm by hand once the customer's app shows success.
public struct UPIQRView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: CheckoutViewModel
    private let onChangeMode: () -> Void
    private let onConfirmed: (Sale) -> Void

    public init(viewModel: CheckoutViewModel, onChangeMode: @escaping () -> Void = {}, onConfirmed: @escaping (Sale) -> Void) {
        self.viewModel = viewModel
        self.onChangeMode = onChangeMode
        self.onConfirmed = onConfirmed
    }

    public var body: some View {
        ScreenScroll {
            if viewModel.upiId.isEmpty {
                ManiEmptyState(icon: .qrCode, title: "No UPI ID yet",
                               message: "Add your UPI ID in Settings → Payments to show a QR here. You can still mark this bill as paid.")
            } else {
                ManiCard {
                    VStack(spacing: ManiSpacing.md) {
                        UPIQRCode(link: UPILink.pay(upiId: viewModel.upiId, payee: viewModel.payeeName,
                                                    amount: viewModel.finalTotal, note: "Bill"))
                            .frame(width: 220, height: 220)
                        Text(viewModel.upiId)
                            .font(theme.typography.secondary)
                            .foregroundStyle(theme.base.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            ManiHeroAmount(Money.format(viewModel.finalTotal), caption: "Scan with any UPI app")
            FlowLayout {
                ForEach(["GPay", "PhonePe", "Paytm", "BHIM"], id: \.self) { app in
                    ManiStatusBadge(app, kind: .neutral)
                }
            }
            if let errorMessage = viewModel.errorMessage {
                ManiNote(errorMessage, kind: .error)
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Mark as received", isLoading: viewModel.isProcessing) {
                    Task { if let sale = await viewModel.confirmSale() { onConfirmed(sale) } }
                }
                ManiButton("Change mode", kind: .outline, action: onChangeMode)
            }
        }
        .navigationTitle("Pay by UPI")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Builds UPI deep links (NPCI `upi://pay`). Shared by checkout, dues reminders and statements.
public enum UPILink {
    public static func pay(upiId: String, payee: String, amount: Double, note: String) -> String {
        var components = URLComponents()
        components.scheme = "upi"
        components.host = "pay"
        components.queryItems = [
            URLQueryItem(name: "pa", value: upiId),
            URLQueryItem(name: "pn", value: payee),
            URLQueryItem(name: "am", value: String(format: "%.2f", amount)),
            URLQueryItem(name: "cu", value: "INR"),
            URLQueryItem(name: "tn", value: note)
        ]
        return components.string ?? "upi://pay?pa=\(upiId)"
    }
}

/// A QR image for any string; falls back to an icon where CoreImage isn't available.
struct UPIQRCode: View {
    @Environment(\.maniTheme) private var theme
    let link: String

    var body: some View {
        #if canImport(UIKit) && canImport(CoreImage.CIFilterBuiltins)
        if let image = Self.image(for: link) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            ManiSwiftUIComponents.IconView(.qrCode, size: 160, color: theme.base.text)
        }
        #else
        ManiSwiftUIComponents.IconView(.qrCode, size: 160, color: theme.base.text)
        #endif
    }

    #if canImport(UIKit) && canImport(CoreImage.CIFilterBuiltins)
    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    #endif
}
