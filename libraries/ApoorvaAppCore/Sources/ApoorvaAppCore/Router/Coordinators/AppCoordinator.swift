import Foundation
import ApoorvaModels
import ApoorvaServices
import ApoorvaModules

@MainActor
@Observable
public final class AppCoordinator {
    enum SessionState {
        case loading
        case onboarding(OnboardingCoordinator)
        case home(HomeTabsCoordinator)
    }

    let appContainer: AppContainer
    var sessionState: SessionState = .loading
    private(set) var phase: SessionPhase = .loading
    var presentedGlobalRoute: GlobalRoute?
    var fullScreenBlockingRoute: GlobalRoute?

    private var snapshot = SessionSnapshot(account: nil, profile: nil)
    private var platform = PlatformConfig()
    private var lastOrgId: String?

    public init(appContainer: AppContainer = AppContainer()) {
        self.appContainer = appContainer
        Task { await observeSession() }
        Task { await observePlatform() }
    }

    var session: AppSession { appContainer.appSession }

    private func observeSession() async {
        for await snapshot in appContainer.servicesContainer.userService.sessionStream {
            guard snapshot != self.snapshot || phase == .loading else { continue }
            self.snapshot = snapshot
            await recompute()
        }
    }

    private func observePlatform() async {
        for await config in appContainer.servicesContainer.platformConfigService.listen() {
            platform = config
            session.updatePlatform(config)
            await recompute()
        }
    }

    /// Re-derives the phase. Coordinators are only rebuilt when the phase key changes, so a
    /// profile update or a platform config change doesn't reset the user's navigation.
    func recompute() async {
        let profile = snapshot.profile
        let orgId = profile?.selectedOrganization?.orgId

        if orgId != lastOrgId {
            if lastOrgId != nil {
                // Switching orgs: never mix two orgs' data in the local cache.
                try? appContainer.repositoryContainer.clearLocalData()
                try? await appContainer.offlineStorageContainer.syncStorage.resetAllSyncStates()
            }
            lastOrgId = orgId
        }

        await session.configure(user: profile, platform: platform)
        if orgId != nil && !session.hasSettingsDoc {
            await session.syncOrgData()
        }

        var org: Organization?
        if let orgId {
            org = try? await appContainer.repositoryContainer.organizationRepository.getOrganization(orgId: orgId)
        }
        var effectivePlatform = platform
        if let orgMin = org?.minVersion, AppVersion(orgMin) > AppVersion(platform.minAppVersion) {
            effectivePlatform.minAppVersion = orgMin
        }

        let newPhase = SessionPhaseReducer.phase(
            account: snapshot.account,
            profile: profile,
            orgStatus: org?.status,
            orgSettings: session.hasSettingsDoc ? session.settings : nil,
            platform: effectivePlatform,
            appVersion: appContainer.appVersion,
            requireEmailVerification: session.isOn(.authEmailVerificationRequired)
        )
        appContainer.themeStore.apply(session: session)
        apply(newPhase)
    }

    private func apply(_ newPhase: SessionPhase) {
        let changed = newPhase.key != phase.key
        phase = newPhase

        switch newPhase {
        case .forceUpdate:
            fullScreenBlockingRoute = .forceUpdate
            return
        case .blocked(let status):
            fullScreenBlockingRoute = .blocked(status: status)
            return
        default:
            if fullScreenBlockingRoute == .forceUpdate || fullScreenBlockingRoute?.isBlockedRoute == true {
                fullScreenBlockingRoute = nil
            }
        }

        guard changed else { return }
        switch newPhase {
        case .loading:
            sessionState = .loading
        case .signedOut:
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .splash))
        case .needsEmailVerification:
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .verifyEmail))
        case .needsProfile, .needsOrgSetup(.chooseVertical):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .chooseVertical))
        case .needsOrgSetup(.shopSetup):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .shopSetup))
        case .needsOrgSetup(.pickLook):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .pickLook))
        case .needsOrgSetup(.openingBalances):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .openingBalances))
        case .ready:
            sessionState = .home(HomeTabsCoordinator(container: appContainer, appCoordinator: self))
            Task { await syncAll() }
        case .forceUpdate, .blocked:
            break
        }
    }

    /// Pulls every collection, then refreshes session-derived state. Safe to call repeatedly.
    func syncAll(force: Bool = false) async {
        await appContainer.repositoryContainer.syncEngine.syncAll(force: force)
        await session.reload()
        appContainer.themeStore.apply(session: session)
    }

    func present(_ route: GlobalRoute) { presentedGlobalRoute = route }
    func presentBlocking(_ route: GlobalRoute) { fullScreenBlockingRoute = route }
    func dismissGlobal() { presentedGlobalRoute = nil }
}
