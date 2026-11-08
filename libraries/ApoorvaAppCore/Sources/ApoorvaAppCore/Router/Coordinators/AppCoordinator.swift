import Foundation

@MainActor
@Observable
public final class AppCoordinator {
    enum SessionState {
        case loading
        case onboarding(OnboardingCoordinator)
        case home(HomeTabsCoordinator)
    }

    let appContainer: AppContainer
    var sessionState: SessionState = .loading
    var presentedGlobalRoute: GlobalRoute?
    var fullScreenBlockingRoute: GlobalRoute?

    public init(appContainer: AppContainer = AppContainer()) {
        self.appContainer = appContainer
        Task {
            await observeSession()
        }
    }

    private func observeSession() async {
        let userService = appContainer.servicesContainer.userService
        for await user in userService.userSessionStream {
            if user == nil {
                sessionState = .onboarding(OnboardingCoordinator(container: appContainer))
            } else {
                sessionState = .home(HomeTabsCoordinator(container: appContainer))
            }
        }
    }

    func present(_ route: GlobalRoute) { presentedGlobalRoute = route }
    func presentBlocking(_ route: GlobalRoute) { fullScreenBlockingRoute = route }
    func dismissGlobal() { presentedGlobalRoute = nil }
}
