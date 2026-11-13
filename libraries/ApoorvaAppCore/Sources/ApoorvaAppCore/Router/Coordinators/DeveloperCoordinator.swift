import Foundation

/// Route state for the Developer settings flow when it is shown on its own (e.g. over the force-update screen).
@MainActor
@Observable
final class DeveloperCoordinator {
    var path: [DeveloperRoute] = []

    func push(_ route: DeveloperRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
}
