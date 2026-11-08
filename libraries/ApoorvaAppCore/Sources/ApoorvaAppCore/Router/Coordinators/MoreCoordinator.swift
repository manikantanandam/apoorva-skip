import Foundation

@MainActor
@Observable
final class MoreCoordinator {
    var path: [MoreRoute] = []
    var presentedSheet: MoreRoute?

    func push(_ route: MoreRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
    func present(_ route: MoreRoute) { presentedSheet = route }
    func dismissSheet() { presentedSheet = nil }
}
