import SwiftUI
import ApoorvaModules

struct CustomersCoordinatorView: View {
    @Bindable var coordinator: CustomersCoordinator
    let container: AppContainer

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            CustomerListView(
                viewModel: container.modulesContainer.makeCustomerListViewModel(),
                onSelectCustomer: { customer in coordinator.push(.detail(phone: customer.phone)) },
                onAddCustomer: { coordinator.push(.add) }
            )
            .navigationTitle("Customers")
            .navigationDestination(for: CustomersRoute.self) { route in
                destination(for: route)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: CustomersRoute) -> some View {
        switch route {
        case .detail:
            NotBuiltView(PlaceholderScreen("Customer ledger"))
        case .add:
            NotBuiltView(PlaceholderScreen("Add customer"))
        case .collect:
            NotBuiltView(PlaceholderScreen("Collect payment"))
        case .reminder:
            NotBuiltView(PlaceholderScreen("WhatsApp reminder"))
        case .statement:
            NotBuiltView(PlaceholderScreen("Statement"))
        }
    }
}
