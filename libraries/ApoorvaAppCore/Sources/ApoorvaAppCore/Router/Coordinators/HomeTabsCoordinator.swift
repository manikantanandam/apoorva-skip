import Foundation

@MainActor
@Observable
final class HomeTabsCoordinator {
    enum Tab: Hashable {
        case home, bills, customers, more
    }

    let container: AppContainer
    /// App-level coordinator, for global sheets (search, sync, locked feature…).
    weak var appCoordinator: AppCoordinator?
    var selectedTab: Tab = .home
    var isPresentingNewBill = false

    let homeCoordinator = HomeCoordinator()
    let billsCoordinator = BillsCoordinator()
    let customersCoordinator = CustomersCoordinator()
    let moreCoordinator = MoreCoordinator()
    let newBillCoordinator = NewBillCoordinator()

    init(container: AppContainer, appCoordinator: AppCoordinator? = nil) {
        self.container = container
        self.appCoordinator = appCoordinator
    }

    func newBillTapped() {
        isPresentingNewBill = true
    }

    func select(_ tab: Tab) {
        selectedTab = tab
    }

    func present(_ route: GlobalRoute) {
        appCoordinator?.present(route)
    }

    /// Shows the "ask your owner" / upgrade screen for something the member can't use.
    func showLocked(_ reason: String) {
        appCoordinator?.present(.lockedFeature(reason: reason))
    }
}
