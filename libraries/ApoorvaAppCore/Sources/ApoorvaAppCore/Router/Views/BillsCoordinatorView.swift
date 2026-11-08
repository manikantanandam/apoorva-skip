import SwiftUI
import ApoorvaModules

struct BillsCoordinatorView: View {
    @Bindable var coordinator: BillsCoordinator
    let container: AppContainer

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            SaleListView(viewModel: container.modulesContainer.makeSaleListViewModel())
                .navigationTitle("Bills")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            coordinator.presentFilters()
                        } label: {
                            Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                .navigationDestination(for: BillsRoute.self) { route in
                    destination(for: route)
                }
        }
        .sheet(isPresented: $coordinator.isPresentingFilters) {
            NotBuiltView(PlaceholderScreen("Bills filters"))
        }
    }

    @ViewBuilder
    private func destination(for route: BillsRoute) -> some View {
        switch route {
        case .detail:
            NotBuiltView(PlaceholderScreen("Bill detail"))
        case .cancel:
            NotBuiltView(PlaceholderScreen("Cancel bill"))
        }
    }
}
