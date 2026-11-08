//
//  MainView.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI
import ApoorvaModules

public struct MainView: View {

    @State private var coordinator = AppCoordinator()

    public init() {}

    public var body: some View {
        Group {
            switch coordinator.sessionState {
            case .loading:
                Text("Loading")
            case .onboarding(let onboardingCoordinator):
                OnboardingCoordinatorView(coordinator: onboardingCoordinator)
            case .home(let homeTabsCoordinator):
                HomeTabsCoordinatorView(coordinator: homeTabsCoordinator)
            }
        }
        .environment(coordinator)
        .overlay(alignment: .topTrailing) {
            EnvironmentBadgeView(environment: coordinator.appContainer.environment)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
        }
        .sheet(item: $coordinator.presentedGlobalRoute) { route in
            GlobalRouteView(route: route)
        }
        .fullScreenCover(item: $coordinator.fullScreenBlockingRoute) { route in
            GlobalRouteView(route: route)
        }
    }
}

#Preview {
    MainView()
}
