//
//  OrgSettings.swift
//  ApoorvaModels
//

import Foundation

/// All org-level configuration, in one doc at `organizations/{orgId}/settings/org`.
/// Every section is optional-with-defaults so a missing doc (legacy orgs) behaves sensibly.
public struct OrgSettings: OrgDocument {
    public static let collection = "settings"
    public static let documentId = "org"

    public var id: String
    public var profile: Profile
    public var tax: Tax
    public var receipt: Receipt
    public var payments: Payments
    public var theme: Theme
    public var flags: Flags
    public var permissions: PermissionMatrix
    public var plan: Plan
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = OrgSettings.documentId,
                profile: Profile = Profile(),
                tax: Tax = Tax(),
                receipt: Receipt = Receipt(),
                payments: Payments = Payments(),
                theme: Theme = Theme(),
                flags: Flags = Flags(),
                permissions: PermissionMatrix = .standard,
                plan: Plan = Plan(),
                updatedAt: Date? = nil,
                isDeleted: Bool = false) {
        self.id = id
        self.profile = profile
        self.tax = tax
        self.receipt = receipt
        self.payments = payments
        self.theme = theme
        self.flags = flags
        self.permissions = permissions
        self.plan = plan
        self.updatedAt = updatedAt
        self.isDeleted = isDeleted
    }

    enum CodingKeys: String, CodingKey {
        case id, profile, tax, receipt, payments, theme, flags, permissions, plan, updatedAt, isDeleted
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? Self.documentId
        profile = (try? c.decode(Profile.self, forKey: .profile)) ?? Profile()
        tax = (try? c.decode(Tax.self, forKey: .tax)) ?? Tax()
        receipt = (try? c.decode(Receipt.self, forKey: .receipt)) ?? Receipt()
        payments = (try? c.decode(Payments.self, forKey: .payments)) ?? Payments()
        theme = (try? c.decode(Theme.self, forKey: .theme)) ?? Theme()
        flags = (try? c.decode(Flags.self, forKey: .flags)) ?? Flags()
        permissions = (try? c.decode(PermissionMatrix.self, forKey: .permissions)) ?? .standard
        plan = (try? c.decode(Plan.self, forKey: .plan)) ?? Plan()
        updatedAt = try? c.decode(Date.self, forKey: .updatedAt)
        isDeleted = (try? c.decode(Bool.self, forKey: .isDeleted)) ?? false
    }

    public struct Profile: Codable, Sendable, Hashable {
        public var shopName: String
        public var phone: String
        public var address: String
        public var billPrefix: String
        public var vertical: Vertical?
        public var setupCompletedAt: Date?
        public var openingBalancesSavedAt: Date?

        public init(shopName: String = "", phone: String = "", address: String = "", billPrefix: String = "A-",
                    vertical: Vertical? = nil, setupCompletedAt: Date? = nil, openingBalancesSavedAt: Date? = nil) {
            self.shopName = shopName
            self.phone = phone
            self.address = address
            self.billPrefix = billPrefix
            self.vertical = vertical
            self.setupCompletedAt = setupCompletedAt
            self.openingBalancesSavedAt = openingBalancesSavedAt
        }
    }

    public enum TaxMode: String, Codable, Sendable, CaseIterable { case off, sameForAll, perItem }

    public struct Tax: Codable, Sendable, Hashable {
        public var mode: TaxMode
        public var ratePercent: Double
        public var inclusive: Bool
        public var gstin: String
        public var showOnReceipt: Bool

        public init(mode: TaxMode = .off, ratePercent: Double = 0, inclusive: Bool = true, gstin: String = "", showOnReceipt: Bool = true) {
            self.mode = mode
            self.ratePercent = ratePercent
            self.inclusive = inclusive
            self.gstin = gstin
            self.showOnReceipt = showOnReceipt
        }
    }

    public enum PaperSize: String, Codable, Sendable, CaseIterable { case mm58, mm80, a4 }

    public struct Receipt: Codable, Sendable, Hashable {
        public var header: String
        public var footer: String
        public var nextBillNumber: Int
        public var showLogo: Bool
        public var showUPIQR: Bool
        public var autoShare: Bool
        public var paperSize: PaperSize
        public var autoPrint: Bool
        public var openCashDrawer: Bool
        public var printerName: String?
        public var language: String

        public init(header: String = "", footer: String = "Thank you! Visit again.", nextBillNumber: Int = 1,
                    showLogo: Bool = false, showUPIQR: Bool = true, autoShare: Bool = false, paperSize: PaperSize = .mm58,
                    autoPrint: Bool = false, openCashDrawer: Bool = false, printerName: String? = nil, language: String = "en") {
            self.header = header
            self.footer = footer
            self.nextBillNumber = nextBillNumber
            self.showLogo = showLogo
            self.showUPIQR = showUPIQR
            self.autoShare = autoShare
            self.paperSize = paperSize
            self.autoPrint = autoPrint
            self.openCashDrawer = openCashDrawer
            self.printerName = printerName
            self.language = language
        }
    }

    public struct Payments: Codable, Sendable, Hashable {
        public var upiId: String
        public var upiVerified: Bool
        /// PaymentMode rawValues shown at checkout.
        public var enabledModes: [String]
        public var askCardLast4: Bool
        public var roundOff: Bool

        public init(upiId: String = "", upiVerified: Bool = false, enabledModes: [String] = PaymentMode.allCases.map(\.rawValue),
                    askCardLast4: Bool = false, roundOff: Bool = true) {
            self.upiId = upiId
            self.upiVerified = upiVerified
            self.enabledModes = enabledModes
            self.askCardLast4 = askCardLast4
            self.roundOff = roundOff
        }
    }

    public enum VisualStyle: String, Codable, Sendable, CaseIterable { case clean, bold }

    public struct Theme: Codable, Sendable, Hashable {
        public var accent: AccentKey?
        public var style: VisualStyle
        public var font: String
        /// When locked, members can't choose their own accent/style (they still pick light/dark).
        public var locked: Bool
        public var allowDark: Bool
        public var fontOnReceipts: Bool

        public init(accent: AccentKey? = nil, style: VisualStyle = .clean, font: String = "System",
                    locked: Bool = false, allowDark: Bool = true, fontOnReceipts: Bool = false) {
            self.accent = accent
            self.style = style
            self.font = font
            self.locked = locked
            self.allowDark = allowDark
            self.fontOnReceipts = fontOnReceipts
        }
    }

    public struct Flags: Codable, Sendable, Hashable {
        public var org: [String: Bool]
        /// storeId → flag → value
        public var stores: [String: [String: Bool]]
        /// role rawValue → flag → value
        public var roles: [String: [String: Bool]]
        public var discountMaxPercentByRole: [String: Double]

        public init(org: [String: Bool] = [:], stores: [String: [String: Bool]] = [:], roles: [String: [String: Bool]] = [:],
                    discountMaxPercentByRole: [String: Double] = [OrgRole.cashier.rawValue: 10, OrgRole.manager.rawValue: 30]) {
            self.org = org
            self.stores = stores
            self.roles = roles
            self.discountMaxPercentByRole = discountMaxPercentByRole
        }
    }

    public enum PlanTier: String, Codable, Sendable, CaseIterable { case trial, free, pro }

    public struct Plan: Codable, Sendable, Hashable {
        public var tier: PlanTier
        public var trialStartedAt: Date?
        public var trialEndingDismissedAt: Date?
        public var usageReminderSnoozedUntil: Date?

        public init(tier: PlanTier = .trial, trialStartedAt: Date? = nil, trialEndingDismissedAt: Date? = nil,
                    usageReminderSnoozedUntil: Date? = nil) {
            self.tier = tier
            self.trialStartedAt = trialStartedAt
            self.trialEndingDismissedAt = trialEndingDismissedAt
            self.usageReminderSnoozedUntil = usageReminderSnoozedUntil
        }
    }
}

/// App-wide config at `platform/config`, written only by superAdmin (the Apoorva console).
public struct PlatformConfig: Codable, Sendable, Hashable {
    public var flags: [String: Bool]
    public var minAppVersion: String
    public var defaultVisualStyle: OrgSettings.VisualStyle
    public var trialDays: Int
    public var freeBillLimit: Int
    public var graceBills: Int
    public var proPriceMonthly: Int
    public var supportPhone: String
    public var enabledVerticals: [String]
    public var updatedAt: Date?

    public init(flags: [String: Bool] = [:], minAppVersion: String = "0.0.0", defaultVisualStyle: OrgSettings.VisualStyle = .clean,
                trialDays: Int = 30, freeBillLimit: Int = 100, graceBills: Int = 10, proPriceMonthly: Int = 199,
                supportPhone: String = "", enabledVerticals: [String] = Vertical.allCases.map(\.rawValue), updatedAt: Date? = nil) {
        self.flags = flags
        self.minAppVersion = minAppVersion
        self.defaultVisualStyle = defaultVisualStyle
        self.trialDays = trialDays
        self.freeBillLimit = freeBillLimit
        self.graceBills = graceBills
        self.proPriceMonthly = proPriceMonthly
        self.supportPhone = supportPhone
        self.enabledVerticals = enabledVerticals
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case flags, minAppVersion, defaultVisualStyle, trialDays, freeBillLimit, graceBills, proPriceMonthly, supportPhone, enabledVerticals, updatedAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PlatformConfig()
        flags = (try? c.decode([String: Bool].self, forKey: .flags)) ?? defaults.flags
        minAppVersion = (try? c.decode(String.self, forKey: .minAppVersion)) ?? defaults.minAppVersion
        defaultVisualStyle = (try? c.decode(OrgSettings.VisualStyle.self, forKey: .defaultVisualStyle)) ?? defaults.defaultVisualStyle
        trialDays = (try? c.decode(Int.self, forKey: .trialDays)) ?? defaults.trialDays
        freeBillLimit = (try? c.decode(Int.self, forKey: .freeBillLimit)) ?? defaults.freeBillLimit
        graceBills = (try? c.decode(Int.self, forKey: .graceBills)) ?? defaults.graceBills
        proPriceMonthly = (try? c.decode(Int.self, forKey: .proPriceMonthly)) ?? defaults.proPriceMonthly
        supportPhone = (try? c.decode(String.self, forKey: .supportPhone)) ?? defaults.supportPhone
        enabledVerticals = (try? c.decode([String].self, forKey: .enabledVerticals)) ?? defaults.enabledVerticals
        updatedAt = try? c.decode(Date.self, forKey: .updatedAt)
    }
}
