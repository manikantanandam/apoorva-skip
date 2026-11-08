import SwiftUI
import ApoorvaModules

struct HomeTabsCoordinatorView: View {
    @Bindable var coordinator: HomeTabsCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeCoordinatorView(coordinator: coordinator.homeCoordinator, container: coordinator.container)
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(HomeTabsCoordinator.Tab.home)

            BillsCoordinatorView(coordinator: coordinator.billsCoordinator, container: coordinator.container)
                .tabItem { Label("Bills", systemImage: "doc.text.fill") }
                .tag(HomeTabsCoordinator.Tab.bills)

            CustomersCoordinatorView(coordinator: coordinator.customersCoordinator, container: coordinator.container)
                .tabItem { Label("Customers", systemImage: "person.3.fill") }
                .tag(HomeTabsCoordinator.Tab.customers)

            MoreCoordinatorView(coordinator: coordinator.moreCoordinator, container: coordinator.container)
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
                .tag(HomeTabsCoordinator.Tab.more)
        }
        .tint(.blue)
        .overlay(alignment: .bottom) {
            Button(action: coordinator.newBillTapped) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(.blue))
                    .shadow(radius: 4)
            }
            .offset(y: -18)
        }
        .overlay(alignment: .topTrailing) {
            EnvironmentBadgeView(environment: coordinator.container.environment)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
        }
        .fullScreenCover(isPresented: $coordinator.isPresentingNewBill) {
            NewBillCoordinatorView(coordinator: coordinator.newBillCoordinator, container: coordinator.container)
        }
    }
}
