//
//  FeatureFlags.swift
//  ApoorvaFeatureFlags
//

import Foundation

/// The docs/05 flag catalogue. Raw values are the flag keys used in config docs.
public enum FeatureFlag: String, Codable, Sendable, CaseIterable, Hashable {
    // billing — grouped under the "billing" Remote Config parameter
    case creditSales = "billing.credit_sales"
    case returns = "billing.returns"
    case holdBills = "billing.hold_bills"
    case splitPayment = "billing.split_payment"
    case staffCommission = "billing.staff_commission"
    case calculatorMode = "billing.calculator_mode"
    case wholesalePrice = "billing.wholesale_price"
    case warranty = "billing.warranty"

    // printing — grouped under "printing"
    case bluetoothPrinting = "printing.bluetooth"

    // inventory — grouped under "inventory"
    case inventoryEdit = "inventory.edit"

    // insights — grouped under "insights"
    case insightsView = "insights.view"
    case insightsExport = "insights.export"

    // standalone modules — each its own one-field group, e.g. "orders" → {"enabled": true}
    case orders
    case suppliers
    case expenses

    // staff — grouped under "staff"
    case staffAttendance = "staff.attendance"

    // offers — grouped under "offers"
    case offersMessages = "offers.messages"

    // summary — grouped under "summary"
    case summaryWhatsAppAuto = "summary.whatsapp_auto"

    // plan — grouped under "plan"
    case planStaffAccounts = "plan.staff_accounts"
    case planReportsExport = "plan.reports_export"
    case planPackages = "plan.packages"

    // kill — grouped under "kill"
    case killSyncWrites = "kill.sync_writes"

    // auth — grouped under "auth"
    case authPhoneOTP = "auth.phone_otp"
    case authEmailPassword = "auth.email_password"
    case authGoogle = "auth.google"
    case authApple = "auth.apple"
    case authEmailVerificationRequired = "auth.email_verification_required"
    case authRegistrationsOpen = "auth.registrations_open"

    // non-bool, ungrouped
    case minAppVersion = "min_app_version"
    case syncIntervalSec = "sync.interval_sec"

    /// The shape of this flag's value. Non-bool flags are always app-level only (see `isAppOnly`)
    /// since `FlagResolver`'s org/store/role layering is bool-only.
    public var kind: RemoteConfigValueKind {
        switch self {
        case .minAppVersion: return .string
        case .syncIntervalSec: return .number
        default: return .bool
        }
    }

    /// Compiled default. Google and phone OTP ship off: their SDKs/console setup aren't in place yet.
    /// Only meaningful when `kind == .bool` — see `defaultStringValue`/`defaultNumberValue`/`defaultVersionGateValue` otherwise.
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

    /// Only meaningful when `kind == .string`.
    public var defaultStringValue: String {
        switch self {
        case .minAppVersion: return "1.0.0"
        default: return ""
        }
    }

    /// Only meaningful when `kind == .number`.
    public var defaultNumberValue: Double {
        switch self {
        case .syncIntervalSec: return 30
        default: return 0
        }
    }

    /// Only meaningful when `kind == .versionGate`. No version-gated flag exists yet.
    public var defaultVersionGateValue: VersionGateValue { VersionGateValue(enabled: false) }

    /// App-level only: orgs/stores/roles can't change these. Non-bool flags are always app-only —
    /// `FlagResolver`'s org/store/role layering only understands bool values.
    public var isAppOnly: Bool {
        kind != .bool || rawValue.hasPrefix("auth.") || rawValue.hasPrefix("kill.")
    }

    public var title: String {
        rawValue.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: ".", with: " · ").capitalized
    }

    /// Every bool flag is grouped into a shared JSON-object Remote Config parameter — dot-namespaced
    /// flags (e.g. `billing.credit_sales`) by their namespace, a standalone app module (`orders`,
    /// `suppliers`, `expenses`) into its own group named after itself (value `{"enabled": Bool}`,
    /// see `remoteConfigFieldName`), anything else ungrouped into the `misc` catch-all — so a
    /// flag's parameter never changes `valueType` later (bool → object) and never needs a forced
    /// update for legacy clients. Only non-bool flags (just `min_app_version` today) stay flat.
    public var remoteConfigGroupKey: String? {
        guard kind == .bool else { return nil }
        if let dot = rawValue.firstIndex(of: ".") { return String(rawValue[..<dot]) }
        switch self {
        case .orders, .suppliers, .expenses: return rawValue
        default: return "misc"
        }
    }

    /// This flag's field name within its `remoteConfigGroupKey` JSON object: `"enabled"` for a
    /// standalone module (its own one-member group), the dot-suffix for a namespaced flag, or the
    /// rawValue itself for anything else (e.g. inside `misc`).
    public var remoteConfigFieldName: String {
        switch self {
        case .orders, .suppliers, .expenses: return "enabled"
        default: break
        }
        guard let dot = rawValue.firstIndex(of: ".") else { return rawValue }
        return String(rawValue[rawValue.index(after: dot)...])
    }

    /// The literal Remote Config parameter name to create in the Firebase console / fetch at
    /// runtime: the group key for grouped flags, the rawValue otherwise.
    public var remoteConfigParameterKey: String { remoteConfigGroupKey ?? rawValue }
}

public enum FlagSource: String, Sendable, Equatable {
    case compiled, app, org, store, role
}

public struct FlagResolution: Sendable, Equatable {
    public let isOn: Bool
    public let source: FlagSource
}

/// Pure flag resolution. Start from the app value (or compiled default), and each lower level (org → store → role) may only
/// turn a flag *off*, never back on — except where the app default is off, in which case the
/// org may opt in (e.g. `billing.warranty`).
public enum FlagResolver {
    public static func resolve(_ flag: FeatureFlag,
                               app: [String: Bool] = [:],
                               org: [String: Bool] = [:],
                               store: [String: Bool] = [:],
                               role: [String: Bool] = [:]) -> FlagResolution {
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
