import Foundation

/// App-wide sheets (`present`) and blocking full-screen covers (`presentBlocking`).
enum GlobalRoute: Hashable, Identifiable {
    case search
    case sync
    case conflict(id: String)
    case notifications
    case lockedFeature(reason: String)
    case forceUpdate
    case help
    case planLimit
    case trialEnding
    /// A suspended/blocked org's staff see this instead of the app (design 125).
    case blocked(status: String)

    var id: Self { self }

    var isBlockedRoute: Bool {
        if case .blocked = self { return true }
        return false
    }
}
