//
//  CoordinatorTests.swift
//  ApoorvaAppCore
//

import Testing
@testable import ApoorvaAppCore

@MainActor
struct HomeCoordinatorTests {
    @Test func pushAppendsToPath() {
        let coordinator = HomeCoordinator()
        coordinator.push(.storeSwitcher)
        #expect(coordinator.path == [.storeSwitcher])
    }

    @Test func popRemovesLastWhenNonEmpty() {
        let coordinator = HomeCoordinator()
        coordinator.push(.storeSwitcher)
        coordinator.push(.planUsage)
        coordinator.pop()
        #expect(coordinator.path == [.storeSwitcher])
    }

    @Test func popOnEmptyPathIsNoOp() {
        let coordinator = HomeCoordinator()
        coordinator.pop()
        #expect(coordinator.path.isEmpty)
    }

    @Test func popToRootClearsPath() {
        let coordinator = HomeCoordinator()
        coordinator.push(.storeSwitcher)
        coordinator.push(.firstRunGuide)
        coordinator.popToRoot()
        #expect(coordinator.path.isEmpty)
    }
}

@MainActor
struct MoreCoordinatorTests {
    @Test func pushAndPresentAreIndependent() {
        let coordinator = MoreCoordinator()
        coordinator.push(.settings(.account))
        coordinator.present(.admin(.selectOrganization))
        #expect(coordinator.path == [.settings(.account)])
        #expect(coordinator.presentedSheet == .admin(.selectOrganization))
    }

    @Test func dismissSheetClearsPresentedRoute() {
        let coordinator = MoreCoordinator()
        coordinator.present(.help)
        coordinator.dismissSheet()
        #expect(coordinator.presentedSheet == nil)
    }
}

@MainActor
struct BillsCoordinatorTests {
    @Test func filtersPresentationToggles() {
        let coordinator = BillsCoordinator()
        coordinator.presentFilters()
        #expect(coordinator.isPresentingFilters)
        coordinator.dismissFilters()
        #expect(!coordinator.isPresentingFilters)
    }
}

@MainActor
struct HomeTabsCoordinatorTests {
    @Test func newBillTappedPresentsWithoutChangingSelectedTab() {
        let coordinator = HomeTabsCoordinator(container: AppContainer())
        coordinator.selectedTab = .bills
        coordinator.newBillTapped()
        #expect(coordinator.isPresentingNewBill)
        #expect(coordinator.selectedTab == .bills)
    }
}

struct RouteHashableTests {
    @Test func customersRouteEqualityIsByCase() {
        #expect(CustomersRoute.detail(customerId: "1") == .detail(customerId: "1"))
        #expect(CustomersRoute.detail(customerId: "1") != .detail(customerId: "2"))
        #expect(CustomersRoute.detail(customerId: "1") != .add)
    }

    @Test func moreRouteNestedEqualityIsByCase() {
        #expect(MoreRoute.admin(.members) == .admin(.members))
        #expect(MoreRoute.admin(.members) != .admin(.stores))
    }
}
