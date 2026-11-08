import SwiftUI

struct HomeCoordinatorView: View {
    @Bindable var coordinator: HomeCoordinator
    let container: AppContainer

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            NotBuiltView(PlaceholderScreen("Home"))
                .navigationDestination(for: HomeRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .storeSwitcher:
            NotBuiltView(PlaceholderScreen("Store switcher"))
        case .firstRunGuide:
            NotBuiltView(PlaceholderScreen("First-run guide"))
        case .planUsage:
            NotBuiltView(PlaceholderScreen("Plan usage"))
        }
    }
}
