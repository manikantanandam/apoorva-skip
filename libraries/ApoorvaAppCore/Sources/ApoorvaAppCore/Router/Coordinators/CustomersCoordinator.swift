import Foundation

@MainActor
@Observable
final class CustomersCoordinator {
    var path: [CustomersRoute] = []

    func push(_ route: CustomersRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
}
