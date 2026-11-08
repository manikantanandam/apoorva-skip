import Foundation

@MainActor
@Observable
final class BillsCoordinator {
    var path: [BillsRoute] = []
    var isPresentingFilters = false

    func push(_ route: BillsRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
    func presentFilters() { isPresentingFilters = true }
    func dismissFilters() { isPresentingFilters = false }
}
