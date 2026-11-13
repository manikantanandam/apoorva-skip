import Foundation
import ApoorvaModels

@MainActor
@Observable
final class NewBillCoordinator {
    var path: [NewBillRoute] = []
    var presentedSheet: NewBillSheet?
    /// A cart to start the next New Bill session with (taken once by the view).
    var pendingCart: PosCart?
    var pendingHeldBillId: String?

    func push(_ route: NewBillRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }
    func present(_ sheet: NewBillSheet) { presentedSheet = sheet }
    func dismissSheet() { presentedSheet = nil }

    /// Hands over the pending cart, if any, and clears it.
    func takePendingCart() -> (cart: PosCart, heldBillId: String?)? {
        guard let cart = pendingCart else { return nil }
        defer {
            pendingCart = nil
            pendingHeldBillId = nil
        }
        return (cart, pendingHeldBillId)
    }
}
