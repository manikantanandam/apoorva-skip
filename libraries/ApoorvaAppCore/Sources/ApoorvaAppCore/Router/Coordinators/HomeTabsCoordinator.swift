import Foundation
import ApoorvaModels

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

    /// Opens New Bill with a cart already filled in: a customer attached, an order's balance, a held bill.
    func startBill(with cart: PosCart, heldBillId: String? = nil) {
        newBillCoordinator.pendingCart = cart
        newBillCoordinator.pendingHeldBillId = heldBillId
        newBillCoordinator.popToRoot()
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

    // MARK: - Cross-tab navigation

    func showMore(_ route: MoreRoute) {
        selectedTab = .more
        moreCoordinator.popToRoot()
        moreCoordinator.push(route)
    }

    func showCustomers(_ route: CustomersRoute? = nil) {
        selectedTab = .customers
        customersCoordinator.popToRoot()
        if let route { customersCoordinator.push(route) }
    }

    func showBill(_ saleId: String) {
        selectedTab = .bills
        billsCoordinator.popToRoot()
        billsCoordinator.push(.detail(billId: saleId))
    }

    func showBills() {
        selectedTab = .bills
        billsCoordinator.popToRoot()
    }
}
