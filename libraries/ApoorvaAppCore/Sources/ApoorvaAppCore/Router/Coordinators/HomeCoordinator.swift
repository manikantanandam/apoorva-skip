import Foundation

@MainActor
@Observable
final class HomeCoordinator {
    var path: [HomeRoute] = []
    var presentedSheet: HomeRoute?

    func push(_ route: HomeRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
    func present(_ route: HomeRoute) { presentedSheet = route }
    func dismissSheet() { presentedSheet = nil }
}
