import SwiftUI

struct GlobalRouteView: View {
    let route: GlobalRoute

    var body: some View {
        switch route {
        case .search:
            NotBuiltView(PlaceholderScreen("Search"))
        case .sync:
            NotBuiltView(PlaceholderScreen("Sync status"))
        case .conflict:
            NotBuiltView(PlaceholderScreen("Conflict"))
        case .notifications:
            NotBuiltView(PlaceholderScreen("Notifications"))
        case .lockedFeature:
            NotBuiltView(PlaceholderScreen("Locked feature"))
        case .forceUpdate:
            NotBuiltView(PlaceholderScreen("Force update"))
        case .help:
            NotBuiltView(PlaceholderScreen("Help"))
        case .planLimit:
            NotBuiltView(PlaceholderScreen("Plan limit"))
        case .trialEnding:
            NotBuiltView(PlaceholderScreen("Trial ending"))
        case .blocked:
            NotBuiltView(PlaceholderScreen("Account paused"))
        }
    }
}
