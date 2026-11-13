import SwiftUI
import ApoorvaModules
import ManiLogger

/// Developer settings in its own `NavigationStack`, for places outside the More tab.
struct DeveloperCoordinatorView: View {
    @State private var coordinator = DeveloperCoordinator()
    let container: AppContainer

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            DeveloperRouteView(route: .hub, container: container, push: coordinator.push)
                .navigationDestination(for: DeveloperRoute.self) { route in
                    DeveloperRouteView(route: route, container: container, push: coordinator.push)
                }
        }
    }
}

/// One Developer screen; shared by the More tab's path and `DeveloperCoordinatorView`.
struct DeveloperRouteView: View {
    let route: DeveloperRoute
    let container: AppContainer
    let push: (DeveloperRoute) -> Void

    var body: some View {
        switch route {
        case .hub:
            DeveloperHubRouteView(
                container: container,
                onOpenEnvironment: { push(.environment) },
                onOpenFlags: { push(.flags) },
                onOpenLogs: { push(.logs) }
            )
        case .environment:
            if let viewModel = container.makeDeveloperSettingsViewModel() {
                EnvironmentSwitchView(viewModel: viewModel)
            } else {
                NotBuiltView(PlaceholderScreen("Environment"))
            }
        case .flags:
            if let viewModel = container.makeFlagOverridesViewModel() {
                FlagOverridesView(viewModel: viewModel)
            } else {
                NotBuiltView(PlaceholderScreen("Feature flags"))
            }
        case .logs:
            if let viewModel = container.makeLogViewerViewModel() {
                LogViewerView(viewModel: viewModel)
            } else {
                NotBuiltView(PlaceholderScreen("Logs"))
            }
        }
    }
}

/// Holds the hub's view model so it isn't rebuilt each time the navigation destination re-evaluates.
private struct DeveloperHubRouteView: View {
    @State private var viewModel: DeveloperSettingsViewModel?
    let container: AppContainer
    let onOpenEnvironment: () -> Void
    let onOpenFlags: () -> Void
    let onOpenLogs: () -> Void

    var body: some View {
        if let viewModel {
            DeveloperSettingsView(viewModel: viewModel,
                                  onOpenEnvironment: onOpenEnvironment,
                                  onOpenFlags: onOpenFlags,
                                  onOpenLogs: onOpenLogs)
        } else {
            NotBuiltView(PlaceholderScreen("Developer"))
                .task { viewModel = container.makeDeveloperSettingsViewModel() }
        }
    }
}
