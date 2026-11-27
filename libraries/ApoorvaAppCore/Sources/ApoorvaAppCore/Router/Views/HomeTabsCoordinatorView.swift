import SwiftUI
import ApoorvaModules
import ManiSwiftUIComponents

struct HomeTabsCoordinatorView: View {
    @Bindable var coordinator: HomeTabsCoordinator
    @Environment(\.maniTheme) var theme

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeCoordinatorView(tabs: coordinator, coordinator: coordinator.homeCoordinator, container: coordinator.container)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(HomeTabsCoordinator.Tab.home)

            BillsCoordinatorView(tabs: coordinator, coordinator: coordinator.billsCoordinator, container: coordinator.container)
                .tabItem { Label("Bills", systemImage: ManiSymbol.name("list.bullet.rectangle")) }
                .tag(HomeTabsCoordinator.Tab.bills)

            CustomersCoordinatorView(tabs: coordinator, coordinator: coordinator.customersCoordinator, container: coordinator.container)
                .tabItem { Label("Customers", systemImage: ManiSymbol.name("person.2")) }
                .tag(HomeTabsCoordinator.Tab.customers)

            MoreCoordinatorView(tabs: coordinator, coordinator: coordinator.moreCoordinator, container: coordinator.container)
                .tabItem { Label("More", systemImage: "ellipsis") }
                .tag(HomeTabsCoordinator.Tab.more)
        }
        .tint(theme.accent.accent)
        .overlay(alignment: .bottom) {
            if coordinator.container.appSession.can(.createBill) && showsNewBillButton {
                newBillButton
                    .offset(y: -18)
            }
        }
        .fullScreenCover(isPresented: $coordinator.isPresentingNewBill) {
            NewBillCoordinatorView(coordinator: coordinator.newBillCoordinator, container: coordinator.container)
        }
    }

    /// On Android the window shrinks when the keyboard opens and the overlay rides up with it, covering forms'
    /// Save buttons (`ignoresSafeArea(.keyboard)` doesn't help there), so the button shows only on tab roots.
    private var showsNewBillButton: Bool {
        #if os(Android)
        coordinator.isAtTabRoot
        #else
        true
        #endif
    }

    /// Raised 52pt "New bill" button: a circle in Clean, an accent square in Bold (docs/04).
    private var newBillButton: some View {
        Button(action: coordinator.newBillTapped) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.accent.on)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: theme.style == .bold ? 14 : 26, style: .continuous)
                        .fill(theme.accent.accent)
                )
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .accessibilityLabel("New bill")
    }
}
