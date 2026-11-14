//
//  VerticalTests.swift
//  ApoorvaModels
//

import Testing
import Foundation
@testable import ApoorvaModels

@Suite("Vertical Model Tests")
struct VerticalTests {

    @Test("Titles and subtitles are non-empty for every vertical")
    func titles() {
        #expect(Vertical.kirana.title == "Kirana / General")
        #expect(Vertical.fancy.title == "Fancy & Gifts")
        #expect(Vertical.jewellery.title == "One-gram Jewellery")
        #expect(Vertical.parlour.title == "Beauty Parlour")
        for vertical in Vertical.allCases {
            #expect(!vertical.subtitle.isEmpty)
        }
    }

    @Test("Default accent and billing style per vertical")
    func accentAndBilling() {
        #expect(Vertical.kirana.defaultAccent == .sage)
        #expect(Vertical.fancy.defaultAccent == .plum)
        #expect(Vertical.jewellery.defaultAccent == .brass)
        #expect(Vertical.parlour.defaultAccent == .rose)
        #expect(Vertical.kirana.billingStyle == .searchList)
        #expect(Vertical.fancy.billingStyle == .tileGrid)
        #expect(Vertical.jewellery.billingStyle == .catalog)
        #expect(Vertical.parlour.billingStyle == .services)
    }

    @Test("Default flags seed the expected features")
    func defaultFlags() {
        #expect(Vertical.kirana.defaultFlags == [FeatureFlag.orders.rawValue: true])
        #expect(Vertical.fancy.defaultFlags == [FeatureFlag.warranty.rawValue: true])
        #expect(Vertical.jewellery.defaultFlags == [FeatureFlag.orders.rawValue: true])
        #expect(Vertical.parlour.defaultFlags == [FeatureFlag.staffCommission.rawValue: true,
                                                   FeatureFlag.planPackages.rawValue: true])
    }

    @Test("Home highlight titles per vertical")
    func highlights() {
        #expect(Vertical.kirana.homeHighlightTitles.third == "Cash in hand")
        #expect(Vertical.kirana.homeHighlightTitles.fourth == "Dues")
        #expect(Vertical.fancy.homeHighlightTitles.fourth == "Low stock")
        #expect(Vertical.jewellery.homeHighlightTitles.third == "Top design")
        #expect(Vertical.parlour.homeHighlightTitles.fourth == "Packages used")
    }

    @Test("AccentKey titles")
    func accentTitles() {
        let expected: [AccentKey: String] = [.ink: "Indigo", .sage: "Teal", .plum: "Orchid",
                                             .brass: "Gold", .rose: "Rose", .slate: "Slate"]
        for key in AccentKey.allCases {
            #expect(key.title == expected[key])
        }
    }

    @Test("Raw values decode from strings")
    func rawValues() throws {
        let vertical = try JSONDecoder().decode(Vertical.self, from: Data("\"parlour\"".utf8))
        #expect(vertical == .parlour)
        #expect(BillingStyle(rawValue: "tileGrid") == .tileGrid)
    }
}
