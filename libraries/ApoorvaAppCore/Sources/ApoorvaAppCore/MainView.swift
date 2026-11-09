//
//  MainView.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI
import ApoorvaModules
import ManiSwiftUIComponents

public struct MainView: View {

    @State private var coordinator = AppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        Group {
            switch coordinator.sessionState {
            case .loading:
                LaunchView()
            case .onboarding(let onboardingCoordinator):
                OnboardingCoordinatorView(coordinator: onboardingCoordinator)
            case .home(let homeTabsCoordinator):
                HomeTabsCoordinatorView(coordinator: homeTabsCoordinator)
            }
        }
        .environment(coordinator)
        .environment(coordinator.appContainer.appSession)
        .overlay(alignment: .topTrailing) {
            EnvironmentBadgeView(environment: coordinator.appContainer.environment)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
        }
        .sheet(item: $coordinator.presentedGlobalRoute) { route in
            GlobalRouteView(route: route, coordinator: coordinator)
                .maniTheme(from: coordinator.appContainer.themeStore)
        }
        .fullScreenCover(item: $coordinator.fullScreenBlockingRoute) { route in
            GlobalRouteView(route: route, coordinator: coordinator)
                .maniTheme(from: coordinator.appContainer.themeStore)
        }
        .maniTheme(from: coordinator.appContainer.themeStore)
        .onOpenURL { url in coordinator.handle(url: url) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, case .ready = coordinator.phase {
                Task { await coordinator.syncAll() }
            }
        }
    }
}

/// Shown while the session resolves: the brand mark (same look as the splash screen).
private struct LaunchView: View {
    @Environment(\.maniTheme) private var theme

    var body: some View {
        VStack(spacing: ManiSpacing.sm) {
            Text("Apoorva")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(theme.accent.accent)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.base.background.ignoresSafeArea())
    }
}

#Preview {
    MainView()
}
