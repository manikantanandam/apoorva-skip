//
//  MoreMenuView.swift
//  ApoorvaModules
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels

/// Every destination reachable from the More tab. The coordinator maps these to routes.
public enum MoreMenuItem: Hashable, Sendable {
    case orders, heldBills, warranty
    case inventory, suppliers, reorder
    case cashflow, expenses, summary, insights
    case staff, attendance, salary
    case settings, admin, console, help, developer
}

/// Counts shown next to menu chips ("Orders · 4"). Nil hides the count.
public struct MoreMenuCounts: Sendable, Equatable {
    public var openOrders: Int?
    public var heldBills: Int?
    public var reorder: Int?
    public var suppliersDue: Int?

    public init(openOrders: Int? = nil, heldBills: Int? = nil, reorder: Int? = nil, suppliersDue: Int? = nil) {
        self.openOrders = openOrders
        self.heldBills = heldBills
        self.reorder = reorder
        self.suppliersDue = suppliersDue
    }
}

/// Design 96: groups as chip rows (Sell · Stock · Money · People), then Settings / Admin / Help.
/// Items the member can't use are hidden (docs/10: UI hides, view models guard).
public struct MoreMenuView: View {
    @Environment(\.maniTheme) private var theme
    private let session: AppSession
    private let counts: MoreMenuCounts
    private let showsDeveloper: Bool
    private let onSelect: (MoreMenuItem) -> Void
    private let onSearch: () -> Void

    public init(session: AppSession, counts: MoreMenuCounts, showsDeveloper: Bool,
                onSelect: @escaping (MoreMenuItem) -> Void, onSearch: @escaping () -> Void) {
        self.session = session
        self.counts = counts
        self.showsDeveloper = showsDeveloper
        self.onSelect = onSelect
        self.onSearch = onSearch
    }

    public var body: some View {
        ScreenScroll {
            ManiAppBar(title: "More") {
                EmptyView()
            } trailing: {
                Button(action: onSearch) {
                    ManiSwiftUIComponents.IconView(.search, size: 18, color: theme.base.text)
                }
            }
            ScreenSubtitle(text: "\(session.displayShopName) · \(session.role.title)")

            group("Sell", items: sellItems)
            group("Stock", items: stockItems)
            group("Money", items: moneyItems)
            group("People", items: peopleItems)

            RowsCard {
                NavRow(icon: .settings, title: "Settings", subtitle: "Billing style, printer, tax, language") { onSelect(.settings) }
                if session.can(.admin) {
                    Divider()
                    NavRow(icon: .shield, title: "Admin", subtitle: "Stores, staff & roles, theme") { onSelect(.admin) }
                }
                if session.isSuperAdmin {
                    Divider()
                    NavRow(icon: .globe, title: "Apoorva Console", subtitle: "Organisations, flags, support") { onSelect(.console) }
                }
                Divider()
                NavRow(icon: .help, title: "Help & feedback", subtitle: "Guides, WhatsApp support") { onSelect(.help) }
                if showsDeveloper {
                    Divider()
                    NavRow(icon: .key, title: "Developer", subtitle: "Environment, flags, logs") { onSelect(.developer) }
                }
            }
        }
    }

    private typealias Item = (item: MoreMenuItem, title: String, count: Int?)

    private var sellItems: [Item] {
        var items: [Item] = []
        if session.isOn(.orders) { items.append((.orders, "Orders", counts.openOrders)) }
        if session.isOn(.holdBills) { items.append((.heldBills, "Held bills", counts.heldBills)) }
        if session.isOn(.warranty) { items.append((.warranty, "Warranty", nil)) }
        return items
    }

    private var stockItems: [Item] {
        var items: [Item] = [(.inventory, "Inventory", nil)]
        if session.isOn(.suppliers) && session.can(.purchases) { items.append((.suppliers, "Suppliers", counts.suppliersDue)) }
        items.append((.reorder, "Reorder", counts.reorder))
        return items
    }

    private var moneyItems: [Item] {
        var items: [Item] = [(.cashflow, "Cashflow", nil)]
        if session.isOn(.expenses) && session.can(.expenses) { items.append((.expenses, "Expenses", nil)) }
        items.append((.summary, "Summary", nil))
        if session.isOn(.insightsView) && session.can(.viewInsights) { items.append((.insights, "Insights", nil)) }
        return items
    }

    private var peopleItems: [Item] {
        var items: [Item] = []
        if session.can(.viewInsights) { items.append((.staff, "Staff", nil)) }
        if session.isOn(.staffAttendance) { items.append((.attendance, "Attendance", nil)) }
        if session.can(.paySalary) { items.append((.salary, "Salary", nil)) }
        return items
    }

    @ViewBuilder
    private func group(_ title: String, items: [Item]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                SectionHeader(title: title)
                FlowLayout {
                    ForEach(items, id: \.item) { entry in
                        ManiChip(entry.count.map { "\(entry.title) · \($0)" } ?? entry.title) {
                            onSelect(entry.item)
                        }
                    }
                }
            }
        }
    }
}
