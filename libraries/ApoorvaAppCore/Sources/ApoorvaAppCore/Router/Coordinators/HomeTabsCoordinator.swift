import Foundation

@MainActor
@Observable
final class HomeTabsCoordinator {
    enum Tab: Hashable {
        case home, bills, customers, more
    }

    let container: AppContainer
    var selectedTab: Tab = .home
    var isPresentingNewBill = false

    let homeCoordinator = HomeCoordinator()
    let billsCoordinator = BillsCoordinator()
    let customersCoordinator = CustomersCoordinator()
    let moreCoordinator = MoreCoordinator()
    let newBillCoordinator = NewBillCoordinator()

    init(container: AppContainer) {
        self.container = container
    }

    func newBillTapped() {
        isPresentingNewBill = true
    }
}
