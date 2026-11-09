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
    private var recomputeGeneration = 0
    /// Invite code from an `apoorva://join/<code>` link, consumed by onboarding.
    var pendingInviteCode: String?

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
        guard !session.isDemo else { return }
        // Each await below can let a newer recompute start. Only the latest one may touch the session or the phase.
        recomputeGeneration += 1
        let generation = recomputeGeneration
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
        guard generation == recomputeGeneration else { return }
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
            let onboarding = OnboardingCoordinator(container: appContainer, root: .splash, appCoordinator: self)
            if let code = pendingInviteCode { onboarding.push(.staffJoin(inviteToken: code)) }
            sessionState = .onboarding(onboarding)
        case .needsEmailVerification:
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .verifyEmail, appCoordinator: self))
        case .needsProfile, .needsOrgSetup(.chooseVertical):
            // Arrived from an invite link: join that shop instead of creating one.
            let root: OnboardingRoute = pendingInviteCode.map { .staffJoin(inviteToken: $0) } ?? .chooseVertical
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: root, appCoordinator: self))
        case .needsOrgSetup(.shopSetup):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .shopSetup, appCoordinator: self))
        case .needsOrgSetup(.pickLook):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .pickLook, appCoordinator: self))
        case .needsOrgSetup(.openingBalances):
            sessionState = .onboarding(OnboardingCoordinator(container: appContainer, root: .openingBalances, appCoordinator: self))
        case .ready:
            pendingInviteCode = nil
            sessionState = .home(HomeTabsCoordinator(container: appContainer, appCoordinator: self))
            Task { await syncAll() }
        case .forceUpdate, .blocked:
            break
        }
    }

    /// Pulls every collection, then re-derives the phase so org status and min version changes take effect.
    func syncAll(force: Bool = false) async {
        await appContainer.repositoryContainer.syncEngine.syncAll(force: force)
        try? await appContainer.repositoryContainer.organizationRepository.sync(force: force)
        await recompute()
    }

    // MARK: - Demo shop

    /// Opens a local-only sample shop (design 02). Only offered while signed out.
    func enterDemo(_ vertical: Vertical) async {
        let repositories = appContainer.repositoryContainer
        try? repositories.clearLocalData()
        // Repositories see a user with no org, so nothing is ever written to Firestore.
        let localUser = AppUser(id: "demo", name: "Demo owner", email: "", role: .admin, status: "active",
                                assignedOrgs: [], createdAt: Date())
        await repositories.userRepository.setDemoUser(localUser)
        try? await appContainer.modulesContainer.makeDemoSeeder().seed(vertical)

        let sessionUser = AppUser(id: "demo", name: "Demo owner", email: "", role: .admin, status: "active",
                                  assignedOrgs: [], createdAt: Date(),
                                  selectedOrganization: OrganizationSnapshot(orgId: "demo", name: DemoSeeder.shopName(for: vertical)))
        await session.startDemo(user: sessionUser, settings: DemoSeeder.settings(for: vertical))
        appContainer.themeStore.apply(session: session)
        phase = .ready(userId: "demo", orgId: "demo")
        sessionState = .home(HomeTabsCoordinator(container: appContainer, appCoordinator: self))
    }

    func exitDemo() async {
        try? appContainer.repositoryContainer.clearLocalData()
        await appContainer.repositoryContainer.userRepository.setDemoUser(nil)
        session.endDemo()
        phase = .loading
        await recompute()
    }

    // MARK: - Deep links

    func handle(url: URL) {
        // apoorva://join/<code>
        guard url.scheme == "apoorva", url.host == "join", let code = url.pathComponents.last, code != "/" else { return }
        pendingInviteCode = code
        // Signed in already: the code is picked up when the account next needs an org.
        if case .onboarding(let onboarding) = sessionState {
            onboarding.push(.staffJoin(inviteToken: code))
        }
    }

    func present(_ route: GlobalRoute) { presentedGlobalRoute = route }
    func presentBlocking(_ route: GlobalRoute) { fullScreenBlockingRoute = route }
    func dismissGlobal() { presentedGlobalRoute = nil }
}
