import Foundation
import SkipFuse
import Observation
import ApoorvaModels
import ApoorvaServices
import ApoorvaModules
import ManiLogger

private let logger = AppLogger(category: .app)

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
    private var recomputeGeneration = 0
    /// Bumped each time a sync step lands data in the local cache, so screens reading it can reload.
    private(set) var syncGeneration = 0
    /// False from sign-in (or an org switch) until the first full sync has finished and the session is reloaded.
    private(set) var isInitialSyncDone = false

    public init(appContainer: AppContainer = AppContainer()) {
        self.appContainer = appContainer
        Task { await observeSession() }
        #if DEBUG
        if let vertical = UITestingConfig.seedVerticalName {
            Task { await UITestSeeder(container: appContainer).run(verticalName: vertical) }
        }
        #endif
        Task { await observePlatform() }
        appContainer.onConfigChanged = { [weak self] in Task { await self?.recompute() } }
        Task { await fetchRemoteConfig() }
    }

    var session: AppSession { appContainer.appSession }

    private func observeSession() async {
        for await snapshot in appContainer.servicesContainer.userService.sessionStream {
            guard snapshot != self.snapshot || phase == .loading else { continue }
            self.snapshot = snapshot
            await recompute()
        }
    }

    /// Launch fetch; the service logs the outcome. A changed `min_app_version` only matters once it is activated.
    private func fetchRemoteConfig() async {
        do {
            try await appContainer.appConfig.fetchAndActivate()
            await recompute()
        } catch {
            // Already logged by the service; the compiled defaults and last activated values stay in effect.
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
        #if DEBUG
        // Seeded UI-test launch: stay on the loading state until the seeder publishes the owner, instead of flashing the signed-out Splash.
        if UITestingConfig.isSeedEnabled && snapshot.account == nil { return }
        #endif
        // Each await below can let a newer recompute start. Only the latest one may touch the session or the phase.
        recomputeGeneration += 1
        let generation = recomputeGeneration
        let profile = snapshot.profile
        let orgId = profile?.selectedOrganization?.orgId

        if orgId != lastOrgId {
            if lastOrgId != nil {
                // Switching orgs: never mix two orgs' data in the local cache.
                try? await appContainer.repositoryContainer.clearLocalData()
                try? await appContainer.offlineStorageContainer.syncStorage.resetAllSyncStates()
                isInitialSyncDone = false
            }
            lastOrgId = orgId
        }

        await session.configure(user: profile, platform: platform)
        guard generation == recomputeGeneration else { return }
        if orgId != nil && !session.hasSettingsDoc {
            await session.syncOrgData()
            guard generation == recomputeGeneration else { return }
        }

        var org: Organization?
        if let orgId {
            org = try? await appContainer.repositoryContainer.organizationRepository.getOrganization(orgId: orgId)
            guard generation == recomputeGeneration else { return }
        }

        let newPhase = SessionPhaseReducer.phase(
            account: snapshot.account,
            profile: profile,
            orgStatus: org?.status,
            orgSettings: session.hasSettingsDoc ? session.settings : nil,
            minAppVersion: appContainer.appConfig.minAppVersion,
            appVersion: appContainer.appVersion,
            requireEmailVerification: session.isOn(.authEmailVerificationRequired)
        )
        guard generation == recomputeGeneration else { return }
        appContainer.themeStore.apply(session: session)
        logger.debug("recompute -> \(newPhase.key)")
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
        if case .ready = newPhase {} else { isInitialSyncDone = false }
        switch newPhase {
        case .loading:
            sessionState = .loading
        case .signedOut:
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .splash, appCoordinator: self))
        case .needsEmailVerification:
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .verifyEmail, appCoordinator: self))
        case .needsProfile, .needsOrgSetup(.chooseVertical):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .chooseVertical, appCoordinator: self))
        case .needsOrgSetup(.shopSetup):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .shopSetup, appCoordinator: self))
        case .needsOrgSetup(.pickLook):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .pickLook, appCoordinator: self))
        case .needsOrgSetup(.openingBalances):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .openingBalances, appCoordinator: self))
        case .ready:
            sessionState = .home(HomeTabsCoordinator(container: appContainer, appCoordinator: self))
            Task { await syncAll() }
        case .forceUpdate, .blocked:
            break
        }
    }

    /// Pulls every collection, then re-derives the phase so org status and min version changes take effect.
    func syncAll(force: Bool = false) async {
        await appContainer.repositoryContainer.syncEngine.syncAll(force: force)
        syncGeneration += 1
        try? await appContainer.repositoryContainer.organizationRepository.sync(force: force)
        await recompute()
        await session.reload()
        isInitialSyncDone = true
        syncGeneration += 1
        await appContainer.modulesContainer.invitationsViewModel.refresh()
        appContainer.themeStore.apply(session: session)
        presentTrialEndingIfNeeded()
    }

    /// Design 48, once a day in the last 3 days of the trial (owner only).
    private func presentTrialEndingIfNeeded() {
        guard session.planStatus.isTrialEnding, session.role == .owner, presentedGlobalRoute == nil else { return }
        if let dismissed = session.settings.plan.trialEndingDismissedAt,
           Date().timeIntervalSince(dismissed) < 86_400 { return }
        present(.trialEnding)
    }

    func present(_ route: GlobalRoute) { presentedGlobalRoute = route }
    func presentBlocking(_ route: GlobalRoute) { fullScreenBlockingRoute = route }
    func dismissGlobal() { presentedGlobalRoute = nil }
}
