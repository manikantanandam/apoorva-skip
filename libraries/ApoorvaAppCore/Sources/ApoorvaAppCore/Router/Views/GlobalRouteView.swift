import SwiftUI
import ApoorvaModules
import ApoorvaModels

struct GlobalRouteView: View {
    let route: GlobalRoute
    let coordinator: AppCoordinator

    private var session: AppSession { coordinator.appContainer.appSession }

    var body: some View {
        NavigationStack {
            content
        }
    }

    @ViewBuilder private var content: some View {
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
            if case .forceUpdate(let required, let current) = coordinator.phase {
                ForceUpdateView(requiredVersion: required, currentVersion: current)
            }
        case .help:
            NotBuiltView(PlaceholderScreen("Help"))
        case .planLimit:
            PlanLimitView(status: session.planStatus,
                          onUpgrade: { openPlan() },
                          onContinue: { coordinator.dismissGlobal() },
                          onRemindTomorrow: { coordinator.dismissGlobal() })
        case .trialEnding:
            TrialEndingView(status: session.planStatus, billsDuringTrial: session.planStatus.billsUsed,
                            onContinuePro: { openPlan() },
                            onSwitchFree: {
                                Task {
                                    try? await session.saveSettings { $0.plan.tier = .free; $0.plan.trialEndingDismissedAt = Date() }
                                    coordinator.dismissGlobal()
                                }
                            })
        case .blocked:
            NotBuiltView(PlaceholderScreen("Account paused"))
        }
    }

    private func openPlan() {
        coordinator.dismissGlobal()
        if case .home(let tabs) = coordinator.sessionState {
            tabs.showMore(.settings(.plan))
        }
    }
}
