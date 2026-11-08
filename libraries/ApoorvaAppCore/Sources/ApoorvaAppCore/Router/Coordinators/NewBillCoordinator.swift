import Foundation

@MainActor
@Observable
final class NewBillCoordinator {
    var path: [NewBillRoute] = []

    func push(_ route: NewBillRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
}
