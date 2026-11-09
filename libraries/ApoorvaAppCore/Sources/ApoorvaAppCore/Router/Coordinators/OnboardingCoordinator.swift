import Foundation

@MainActor
@Observable
final class OnboardingCoordinator {
    let container: AppContainer
    weak var appCoordinator: AppCoordinator?
    /// First screen shown, decided by the session phase (splash, verify email, or a setup step).
    let root: OnboardingRoute
    var path: [OnboardingRoute] = []

    init(container: AppContainer, root: OnboardingRoute = .splash, appCoordinator: AppCoordinator? = nil) {
        self.container = container
        self.root = root
        self.appCoordinator = appCoordinator
    }

    func push(_ route: OnboardingRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
    /// Replaces the whole stack, e.g. moving from sign-in into shop setup.
    func reset(to routes: [OnboardingRoute]) { path = routes }
}
