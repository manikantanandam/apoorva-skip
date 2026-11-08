import Foundation

/// Root of the "More" tab. Groups per docs/04-ui-design.md §2:
/// Sell · Stock · Money · People · Settings · Admin (owner/org admin) ·
/// Apoorva Console (superAdmin) · Developer (debug/developer claim) · Help.
enum MoreRoute: Hashable, Identifiable {
    case sell(SellRoute)
    case stock(StockRoute)
    case money(MoneyRoute)
    case people(PeopleRoute)
    case settings(SettingsRoute)
    case admin(AdminRoute)
    case console(ConsoleRoute)
    case developer(DeveloperRoute)
    case help

    var id: Self { self }
}

enum SellRoute: Hashable {
    case orders
    case orderAdd
    case orderDetail(orderId: String)
    case heldBills
    case warranty
}

enum StockRoute: Hashable {
    case inventory(InventoryRoute)
    case suppliers
    case supplierDetail(supplierId: String)
    case supplierAdd
    case purchaseAdd(supplierId: String?)
    case reorder
}

enum InventoryRoute: Hashable {
    case list
    case add
    case edit(itemId: String)
    case item(itemId: String)
    case adjust(itemId: String)
    case categories
    case bulkImport
}

enum MoneyRoute: Hashable {
    case cashflowHistory
    case cashflowDay(date: Date)
    case cashflowAdd(date: Date)
    case cashflowClose(date: Date)
    case transactions
    case expenses
    case expenseAdd(expenseId: String?)
    case dailySummary
    case insights(InsightsRoute)
}

enum InsightsRoute: Hashable {
    case overview
    case profit
    case items
    case customers
    case staff
    case reports
}

enum PeopleRoute: Hashable {
    case staff
    case attendance
    case salary
}

enum SettingsRoute: Hashable {
    case hub
    case account
    case appearance
    case tax
    case receipts
    case payments
    case printer
    case language
    case backup
    case plan
    case devices
    case signInMethods
}

enum AdminRoute: Hashable {
    case home
    case stores
    case storeDetail(storeId: String)
    case members
    case memberAdd
    case memberDetail(userId: String)
    case permissions
    case theme
    case font
    case features
    case audit
    case invite
    case selectOrganization
}

enum ConsoleRoute: Hashable {
    case home
    case orgs
    case orgDetail(orgId: String)
    case support(orgId: String)
    case block(orgId: String)
    case blockedView
    case analytics
    case flags
    case signInConfig
}

enum DeveloperRoute: Hashable {
    case hub
    case environment
    case flags
    case logs
}
