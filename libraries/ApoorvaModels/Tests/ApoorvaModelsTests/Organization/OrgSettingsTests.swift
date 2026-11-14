//
//  OrgSettingsTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("OrgSettings Tests")
struct OrgSettingsTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    @Test("Defaults for every section")
    func defaults() {
        let settings = OrgSettings()
        #expect(OrgSettings.collection == "settings")
        #expect(settings.id == OrgSettings.documentId)
        #expect(settings.profile.billPrefix == "A-")
        #expect(settings.profile.vertical == nil)
        #expect(settings.tax.mode == .off)
        #expect(settings.tax.inclusive)
        #expect(settings.receipt.footer == "Thank you! Visit again.")
        #expect(settings.receipt.nextBillNumber == 1)
        #expect(settings.receipt.paperSize == .mm58)
        #expect(settings.receipt.language == "en")
        #expect(settings.payments.enabledModes == PaymentMode.allCases.map(\.rawValue))
        #expect(settings.payments.roundOff)
        #expect(settings.theme.style == .clean)
        #expect(settings.theme.font == "System")
        #expect(settings.theme.allowDark)
        #expect(settings.flags.discountMaxPercentByRole[OrgRole.cashier.rawValue] == 10)
        #expect(settings.flags.discountMaxPercentByRole[OrgRole.manager.rawValue] == 30)
        #expect(settings.permissions == .standard)
        #expect(settings.plan.tier == .trial)
        #expect(!settings.isDeleted)
    }

    @Test("Decoding an empty object yields defaults")
    func decodeEmpty() throws {
        let settings = try decode(OrgSettings.self, "{}")
        #expect(settings.id == OrgSettings.documentId)
        #expect(settings.tax == OrgSettings.Tax())
        #expect(settings.permissions == .standard)
        #expect(settings.updatedAt == nil)
        #expect(!settings.isDeleted)
    }

    @Test("Malformed sections fall back to defaults while valid ones are kept")
    func decodeMalformed() throws {
        let json = """
        {"id":"custom","tax":"oops","plan":{"tier":"pro"},"permissions":5,"isDeleted":true,
         "profile":{"shopName":"Glitz","phone":"","address":"","billPrefix":"A-","vertical":"fancy"}}
        """
        let settings = try decode(OrgSettings.self, json)
        #expect(settings.id == "custom")
        #expect(settings.tax == OrgSettings.Tax())
        #expect(settings.permissions == .standard)
        #expect(settings.plan.tier == .pro)
        #expect(settings.isDeleted)
        #expect(settings.profile.shopName == "Glitz")
        #expect(settings.profile.vertical == .fancy)
    }

    @Test("Settings round-trip through Codable")
    func roundTrip() throws {
        var settings = OrgSettings()
        settings.profile.shopName = "Glitz"
        settings.tax = .init(mode: .sameForAll, ratePercent: 5, inclusive: false, gstin: "G1")
        settings.receipt.printerName = "Epson"
        settings.theme.accent = .rose
        settings.flags.org = ["x": true]
        settings.plan.tier = .free
        let decoded = try JSONDecoder().decode(OrgSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.profile == settings.profile)
        #expect(decoded.tax == settings.tax)
        #expect(decoded.receipt == settings.receipt)
        #expect(decoded.theme == settings.theme)
        #expect(decoded.flags == settings.flags)
        #expect(decoded.plan == settings.plan)
    }

    @Test("Nested enums expose all cases")
    func enums() {
        #expect(OrgSettings.TaxMode.allCases.count == 3)
        #expect(OrgSettings.PaperSize.allCases.count == 3)
        #expect(OrgSettings.VisualStyle.allCases.count == 2)
        #expect(OrgSettings.PlanTier.allCases.count == 3)
    }

    @Test("Nested section initialisers store their values")
    func sectionInits() {
        let now = Date(timeIntervalSince1970: 100)
        let profile = OrgSettings.Profile(shopName: "S", phone: "1", address: "A", billPrefix: "B-", vertical: .kirana,
                                          setupCompletedAt: now, openingBalancesSavedAt: now)
        #expect(profile.billPrefix == "B-")
        #expect(profile.setupCompletedAt == now)
        #expect(profile.openingBalancesSavedAt == now)

        let plan = OrgSettings.Plan(tier: .pro, trialStartedAt: now, trialEndingDismissedAt: now, usageReminderSnoozedUntil: now)
        #expect(plan.trialStartedAt == now)
        #expect(plan.usageReminderSnoozedUntil == now)

        let payments = OrgSettings.Payments(upiId: "a@upi", upiVerified: true, enabledModes: ["cash"], askCardLast4: true, roundOff: false)
        #expect(payments.upiVerified)
        #expect(payments.enabledModes == ["cash"])
        #expect(!payments.roundOff)
    }

    // MARK: - PlatformConfig

    @Test("PlatformConfig defaults")
    func platformDefaults() {
        let config = PlatformConfig()
        #expect(config.minAppVersion == "0.0.0")
        #expect(config.trialDays == 30)
        #expect(config.freeBillLimit == 100)
        #expect(config.graceBills == 10)
        #expect(config.proPriceMonthly == 199)
        #expect(config.enabledVerticals == Vertical.allCases.map(\.rawValue))
        #expect(config.defaultVisualStyle == .clean)
    }

    @Test("PlatformConfig decodes empty object to defaults")
    func platformDecodeEmpty() throws {
        let config = try decode(PlatformConfig.self, "{}")
        #expect(config == PlatformConfig())
    }

    @Test("PlatformConfig keeps valid values and falls back on invalid ones")
    func platformDecodePartial() throws {
        let json = """
        {"flags":{"a":true},"minAppVersion":"2.0.0","defaultVisualStyle":"bold","trialDays":"bad",
         "freeBillLimit":5,"graceBills":1,"proPriceMonthly":299,"supportPhone":"108",
         "enabledVerticals":["kirana"],"updatedAt":0}
        """
        let config = try decode(PlatformConfig.self, json)
        #expect(config.flags == ["a": true])
        #expect(config.minAppVersion == "2.0.0")
        #expect(config.defaultVisualStyle == .bold)
        #expect(config.trialDays == 30)
        #expect(config.freeBillLimit == 5)
        #expect(config.graceBills == 1)
        #expect(config.proPriceMonthly == 299)
        #expect(config.supportPhone == "108")
        #expect(config.enabledVerticals == ["kirana"])
        #expect(config.updatedAt != nil)
    }
}
