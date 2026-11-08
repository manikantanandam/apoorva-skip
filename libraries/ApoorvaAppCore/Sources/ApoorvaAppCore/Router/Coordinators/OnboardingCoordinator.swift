import Foundation

@MainActor
@Observable
final class OnboardingCoordinator {
    let container: AppContainer
    var path: [OnboardingRoute] = []

    init(container: AppContainer) {
        self.container = container
    }

    func push(_ route: OnboardingRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
}
