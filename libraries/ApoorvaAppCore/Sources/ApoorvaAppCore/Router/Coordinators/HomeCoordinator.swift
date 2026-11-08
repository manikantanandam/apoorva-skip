import Foundation

@MainActor
@Observable
final class HomeCoordinator {
    var path: [HomeRoute] = []

    func push(_ route: HomeRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
}
