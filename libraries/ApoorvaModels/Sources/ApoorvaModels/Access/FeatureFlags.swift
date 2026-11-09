//
//  FeatureFlags.swift
//  ApoorvaModels
//

import Foundation

/// The docs/05 flag catalogue. Raw values are the flag keys used in config docs.
public enum FeatureFlag: String, Codable, Sendable, CaseIterable, Hashable {
    case creditSales = "billing.credit_sales"
    case returns = "billing.returns"
    case holdBills = "billing.hold_bills"
    case splitPayment = "billing.split_payment"
    case staffCommission = "billing.staff_commission"
    case calculatorMode = "billing.calculator_mode"
    case wholesalePrice = "billing.wholesale_price"
    case warranty = "billing.warranty"
    case bluetoothPrinting = "printing.bluetooth"
    case inventoryEdit = "inventory.edit"
    case insightsView = "insights.view"
    case insightsExport = "insights.export"
    case orders
    case suppliers
    case expenses
    case staffAttendance = "staff.attendance"
    case offersMessages = "offers.messages"
    case summaryWhatsAppAuto = "summary.whatsapp_auto"
    case planStaffAccounts = "plan.staff_accounts"
    case planReportsExport = "plan.reports_export"
    case planPackages = "plan.packages"
    case killSyncWrites = "kill.sync_writes"
    case authPhoneOTP = "auth.phone_otp"
    case authEmailPassword = "auth.email_password"
    case authGoogle = "auth.google"
    case authApple = "auth.apple"
    case authEmailVerificationRequired = "auth.email_verification_required"
    case authRegistrationsOpen = "auth.registrations_open"

    /// Compiled default. Google and phone OTP ship off: their SDKs/console setup aren't in place yet.
    public var defaultValue: Bool {
        switch self {
        case .warranty, .bluetoothPrinting, .insightsExport, .summaryWhatsAppAuto,
             .planStaffAccounts, .planReportsExport, .planPackages, .killSyncWrites,
             .authApple, .authGoogle, .authPhoneOTP:
            return false
        default:
            return true
        }
    }

    /// App-level only: orgs/stores/roles can't change these.
    public var isAppOnly: Bool {
        rawValue.hasPrefix("auth.") || rawValue.hasPrefix("kill.")
    }

    public var title: String {
        rawValue.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ".", with: " · ").capitalized
    }
}

public enum FlagSource: String, Sendable, Equatable {
    case compiled, app, org, store, role, developer
}

public struct FlagResolution: Sendable, Equatable {
    public let isOn: Bool
    public let source: FlagSource
}

/// Pure flag resolution. Precedence: developer override wins outright; otherwise start from
/// the app value (or compiled default), and each lower level (org → store → role) may only
/// turn a flag *off*, never back on — except where the app default is off, in which case the
/// org may opt in (e.g. `billing.warranty`).
public enum FlagResolver {
    public static func resolve(_ flag: FeatureFlag,
                               app: [String: Bool] = [:],
                               org: [String: Bool] = [:],
                               store: [String: Bool] = [:],
                               role: [String: Bool] = [:],
                               developerOverride: Bool? = nil) -> FlagResolution {
        if let developerOverride {
            return FlagResolution(isOn: developerOverride, source: .developer)
        }
        var value = flag.defaultValue
        var source = FlagSource.compiled
        if let appValue = app[flag.rawValue] {
            value = appValue
            source = .app
        }
        guard !flag.isAppOnly else { return FlagResolution(isOn: value, source: source) }

        if let orgValue = org[flag.rawValue], orgValue != value {
            // Orgs can switch off anything. They can switch on an opt-in feature only when the platform left it unset.
            if !orgValue || (!flag.defaultValue && app[flag.rawValue] == nil) {
                value = orgValue
                source = .org
            }
        }
        for (level, values) in [(FlagSource.store, store), (.role, role)] {
            if values[flag.rawValue] == false && value {
                value = false
                source = level
            }
        }
        return FlagResolution(isOn: value, source: source)
    }
}
