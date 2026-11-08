import Foundation

enum GlobalRoute: Hashable, Identifiable {
    case search
    case sync
    case conflict(id: String)
    case notifications
    case lockedFeature(reason: String)
    case forceUpdate
    case help

    var id: Self { self }
}
