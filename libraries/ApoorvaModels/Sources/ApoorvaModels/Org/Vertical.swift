//
//  Vertical.swift
//  ApoorvaModels
//

import Foundation

/// Shop type. Drives the billing style, home dashboard, catalogue fields and default theme.
public enum Vertical: String, Codable, Sendable, CaseIterable, Hashable {
    case kirana, fancy, jewellery, parlour

    public var title: String {
        switch self {
        case .kirana: "Kirana / General"
        case .fancy: "Fancy & Gifts"
        case .jewellery: "One-gram Jewellery"
        case .parlour: "Beauty Parlour"
        }
    }

    public var subtitle: String {
        switch self {
        case .kirana: "Quick search, loose items by weight"
        case .fancy: "Item grid, variants, barcode"
        case .jewellery: "Catalog, design codes, weight"
        case .parlour: "Walk-in services, packages"
        }
    }

    /// Accent key used when nothing more specific is set (see `ThemeResolver`).
    public var defaultAccent: AccentKey {
        switch self {
        case .kirana: .sage
        case .fancy: .plum
        case .jewellery: .brass
        case .parlour: .rose
        }
    }

    public var billingStyle: BillingStyle {
        switch self {
        case .kirana: .searchList
        case .fancy: .tileGrid
        case .jewellery: .catalog
        case .parlour: .services
        }
    }

    /// Flags seeded into a new org of this type.
    public var defaultFlags: [String: Bool] {
        switch self {
        case .kirana: [FeatureFlag.orders.rawValue: true]
        case .fancy: [FeatureFlag.warranty.rawValue: true]
        case .jewellery: [FeatureFlag.orders.rawValue: true]
        case .parlour: [FeatureFlag.staffCommission.rawValue: true, FeatureFlag.planPackages.rawValue: true]
        }
    }

    /// Wording for the per-vertical home KPI that isn't sales or bills.
    public var homeHighlightTitles: (third: String, fourth: String) {
        switch self {
        case .kirana: ("Cash in hand", "Dues")
        case .fancy: ("Top item", "Low stock")
        case .jewellery: ("Top design", "Repeat buyers")
        case .parlour: ("Top service", "Packages used")
        }
    }
}

public enum BillingStyle: String, Codable, Sendable {
    /// Search list with quick + buttons, loose items by weight (kirana).
    case searchList
    /// Three-column item tiles with qty badges (fancy).
    case tileGrid
    /// Two-column catalog with design codes (jewellery).
    case catalog
    /// Services / packages / products with "done by" staff (parlour).
    case services
}

/// Named accents. `ThemeStore` maps these to concrete palettes per Clean/Bold style.
public enum AccentKey: String, Codable, Sendable, CaseIterable, Hashable {
    case ink, sage, plum, brass, rose, slate

    public var title: String {
        switch self {
        case .ink: "Indigo"
        case .sage: "Teal"
        case .plum: "Orchid"
        case .brass: "Gold"
        case .rose: "Rose"
        case .slate: "Slate"
        }
    }
}
