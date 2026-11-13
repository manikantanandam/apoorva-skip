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

    @Test func developerScreensStackOnTheHub() {
        let coordinator = MoreCoordinator()
        coordinator.push(.developer(.hub))
        coordinator.push(.developer(.flags))
        #expect(coordinator.path == [.developer(.hub), .developer(.flags)])
    }

    @Test func dismissSheetClearsPresentedRoute() {
        let coordinator = MoreCoordinator()
        coordinator.present(.help)
        coordinator.dismissSheet()
        #expect(coordinator.presentedSheet == nil)
    }
}

@MainActor
struct DeveloperCoordinatorTests {
    @Test func pushAndPop() {
        let coordinator = DeveloperCoordinator()
        coordinator.push(.flags)
        coordinator.push(.logs)
        #expect(coordinator.path == [.flags, .logs])
        coordinator.pop()
        #expect(coordinator.path == [.flags])
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
        #expect(CustomersRoute.detail(phone: "1") == .detail(phone: "1"))
        #expect(CustomersRoute.detail(phone: "1") != .detail(phone: "2"))
        #expect(CustomersRoute.detail(phone: "1") != .add)
    }

    @Test func moreRouteNestedEqualityIsByCase() {
        #expect(MoreRoute.admin(.members) == .admin(.members))
        #expect(MoreRoute.admin(.members) != .admin(.stores))
        #expect(MoreRoute.money(.insights(.profit)) != .money(.insights(.items)))
    }

    @Test func globalBlockedRouteIsRecognised() {
        #expect(GlobalRoute.blocked(status: "suspended").isBlockedRoute)
        #expect(!GlobalRoute.forceUpdate.isBlockedRoute)
    }
}

@MainActor
struct OnboardingAndTabsCoordinatorTests {
    @Test func onboardingStartsAtTheGivenRootAndResets() {
        let coordinator = OnboardingCoordinator(container: AppContainer(), root: .chooseVertical)
        #expect(coordinator.root == .chooseVertical)
        coordinator.push(.shopSetup)
        coordinator.reset(to: [.pickLook])
        #expect(coordinator.path == [.pickLook])
    }

    @Test func tabsSelectAndPresentWithoutAppCoordinator() {
        let tabs = HomeTabsCoordinator(container: AppContainer())
        tabs.select(.customers)
        #expect(tabs.selectedTab == .customers)
        tabs.present(.search) // no app coordinator attached: must not crash
    }
}
