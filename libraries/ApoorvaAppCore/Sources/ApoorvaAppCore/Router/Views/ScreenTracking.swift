import SwiftUI
import ApoorvaServices

private struct AnalyticsServiceKey: EnvironmentKey {
    static let defaultValue: AnalyticsServicing = NoOpAnalyticsService()
}

extension EnvironmentValues {
    /// Set once in `MainView`; sheets and pushed screens inherit it.
    var analyticsService: AnalyticsServicing {
        get { self[AnalyticsServiceKey.self] }
        set { self[AnalyticsServiceKey.self] = newValue }
    }
}

/// Logs a `screen_view` each time the screen appears, including coming back to it, as GA4 expects.
private struct ScreenTracking: ViewModifier {
    let name: String
    @Environment(\.analyticsService) private var analyticsService

    func body(content: Content) -> some View {
        content.onAppear { analyticsService.logScreenView(name) }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View {
        modifier(ScreenTracking(name: name))
    }

    /// Names the screen `<area>_<route case>`, e.g. `bills_detail`. Associated values (ids, phone numbers) are dropped.
    func trackScreen(_ route: some Hashable, in area: String) -> some View {
        trackScreen("\(area)_\(String(describing: route).prefix { $0 != "(" })")
    }
}
