//
//  SettingsHubView.swift
//  ApoorvaModules
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels

public enum SettingsItem: Hashable, Sendable {
    case appearance, tax, receipts, payments, printer, language, backup, account, plan, devices, signInMethods
}

/// The Settings list behind More → Settings. Shop-wide settings are owner/manager only.
public struct SettingsHubView: View {
    private let session: AppSession
    private let onSelect: (SettingsItem) -> Void

    public init(session: AppSession, onSelect: @escaping (SettingsItem) -> Void) {
        self.session = session
        self.onSelect = onSelect
    }

    private var canEditShop: Bool { session.role == .owner || session.role == .manager }

    public var body: some View {
        ScreenScroll {
            SectionHeader(title: "You")
            RowsCard {
                NavRow(icon: .customer, title: "Account", subtitle: "Profile, security, sign out") { onSelect(.account) }
                Divider()
                NavRow(icon: .palette, title: "Appearance", subtitle: "Light / dark, accent colour") { onSelect(.appearance) }
                Divider()
                NavRow(icon: .globe, title: "Language", subtitle: "App and receipt language") { onSelect(.language) }
                Divider()
                NavRow(icon: .key, title: "Sign-in methods", subtitle: "Phone, Google, email") { onSelect(.signInMethods) }
                Divider()
                NavRow(icon: .device, title: "Devices", subtitle: "Where you're signed in") { onSelect(.devices) }
            }

            if canEditShop {
                SectionHeader(title: "Shop")
                RowsCard {
                    NavRow(icon: .receipt, title: "Receipts", subtitle: "Header, footer, bill numbers") { onSelect(.receipts) }
                    Divider()
                    NavRow(icon: .percent, title: "Tax", value: taxSummary) { onSelect(.tax) }
                    Divider()
                    NavRow(icon: .qrCode, title: "Payments", subtitle: "UPI ID, payment modes") { onSelect(.payments) }
                    Divider()
                    NavRow(icon: .printer, title: "Printer", subtitle: "Bluetooth thermal printer") { onSelect(.printer) }
                    Divider()
                    NavRow(icon: .download, title: "Backup & data", subtitle: "Export, restore") { onSelect(.backup) }
                    Divider()
                    NavRow(icon: .star, title: "Plan", value: session.planStatus.tier.rawValue.capitalized) { onSelect(.plan) }
                }
            }
        }
        .navigationTitle("Settings")
    }

    private var taxSummary: String {
        switch session.settings.tax.mode {
        case .off: "Off"
        case .sameForAll: "\(session.settings.tax.ratePercent.formatted(.number.precision(.fractionLength(0...2))))%"
        case .perItem: "Per item"
        }
    }
}
