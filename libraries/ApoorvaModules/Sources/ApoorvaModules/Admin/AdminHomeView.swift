//
//  AdminHomeView.swift
//  ApoorvaModules
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels

public enum AdminItem: Hashable, Sendable {
    case stores, members, permissions, theme, features, audit, invite
}

/// Design 109: org overview KPIs and the admin sections. Owner only.
public struct AdminHomeView: View {
    private let session: AppSession
    private let memberCount: Int
    private let lastSync: Date?
    private let onSelect: (AdminItem) -> Void

    public init(session: AppSession, memberCount: Int, lastSync: Date?, onSelect: @escaping (AdminItem) -> Void) {
        self.session = session
        self.memberCount = memberCount
        self.lastSync = lastSync
        self.onSelect = onSelect
    }

    private var featuresOn: Int {
        FeatureFlag.allCases.filter { !$0.isAppOnly && session.isOn($0) }.count
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: session.displayShopName)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ManiSpacing.sm) {
                ManiKPITile(title: "Stores", value: "\(max(session.stores.count, 1))", isHighlighted: true)
                ManiKPITile(title: "Staff", value: "\(memberCount)")
                ManiKPITile(title: "Features on", value: "\(featuresOn)")
                ManiKPITile(title: "Last sync", value: lastSync?.timeOnly ?? "—")
            }
            RowsCard {
                NavRow(icon: .store, title: "Stores", subtitle: "Shop details, type, printer") { onSelect(.stores) }
                Divider()
                NavRow(icon: .people, title: "Staff & roles", subtitle: "Invite, roles, store access") { onSelect(.members) }
                Divider()
                NavRow(icon: .shield, title: "Permissions", subtitle: "What each role can do") { onSelect(.permissions) }
                Divider()
                NavRow(icon: .palette, title: "Theme", subtitle: "Colour, Clean / Bold, font, lock") { onSelect(.theme) }
                Divider()
                NavRow(icon: .flag, title: "Features", subtitle: "Turn features on or off") { onSelect(.features) }
                Divider()
                NavRow(icon: .history, title: "Audit log", subtitle: "Who did what, when") { onSelect(.audit) }
            }
        }
        .navigationTitle("Admin")
    }
}
