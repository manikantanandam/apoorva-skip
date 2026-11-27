import SwiftUI
import ApoorvaModules
import ApoorvaModels

extension HomeRoute: Identifiable {
    var id: Self { self }
}

struct HomeCoordinatorView: View {
    let tabs: HomeTabsCoordinator
    @Bindable var coordinator: HomeCoordinator
    let container: AppContainer
    @State var viewModel: HomeViewModel
    @State var syncText = "Syncing…"

    init(tabs: HomeTabsCoordinator, coordinator: HomeCoordinator, container: AppContainer) {
        self.tabs = tabs
        self.coordinator = coordinator
        self.container = container
        let viewModel = container.modulesContainer.makeHomeViewModel(session: container.appSession)
        if !(tabs.appCoordinator?.isInitialSyncDone ?? false) { viewModel.beginAwaitingInitialSync() }
        _viewModel = State(initialValue: viewModel)
    }

    private var session: AppSession { container.appSession }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            HomeView(session: session, viewModel: viewModel, syncText: syncText,
                     invitations: container.modulesContainer.invitationsViewModel,
                     onRefresh: { await tabs.appCoordinator?.syncAll() }, onAction: handle)
                .toolbar(.hidden, for: .navigationBar)
                .trackScreen("home")
                .navigationDestination(for: HomeRoute.self) { route in
                    destination(for: route)
                        .trackScreen(route, in: "home")
                }
                .task { await refreshSyncText() }
        }
        .sheet(item: $coordinator.presentedSheet) { route in
            NavigationStack { destination(for: route).trackScreen(route, in: "home") }
        }
        .onChange(of: tabs.appCoordinator?.syncGeneration) { _, _ in
            // The cache just got server data: show it instead of the pre-sync empty state.
            if tabs.appCoordinator?.isInitialSyncDone == true { viewModel.markSyncSettled() }
            Task {
                await viewModel.load()
                await refreshSyncText()
            }
        }
        .onChange(of: tabs.appCoordinator?.isInitialSyncDone) { _, done in
            // An org switch clears the cache and syncs again: wait for it rather than flashing the guide.
            if done == false { viewModel.beginAwaitingInitialSync() }
        }
        .onChange(of: tabs.isPresentingNewBill) { _, isPresenting in
            if !isPresenting { Task { await viewModel.load() } }
        }
    }

    private func handle(_ action: HomeAction) {
        switch action {
        case .search: tabs.present(.search)
        case .notifications: tabs.present(.notifications)
        case .syncStatus: tabs.present(.sync)
        case .storeSwitcher:
            if session.stores.count > 1 { coordinator.present(.storeSwitcher) }
        case .collectDue: tabs.showCustomers()
        case .cashEntry: tabs.showMore(.money(.cashflowAdd(date: Date())))
        case .addItem: tabs.showMore(.stock(.inventory(.add)))
        case .dayClose: tabs.showMore(.money(.cashflowClose(date: Date())))
        case .seeAllBills: tabs.showBills()
        case .bill(let id): tabs.showBill(id)
        case .restock: tabs.showMore(.stock(.reorder))
        case .catalog: tabs.newBillTapped()
        case .firstRunStep("items"): tabs.showMore(.stock(.inventory(.add)))
        case .firstRunStep("balances"): coordinator.push(.openingBalances)
        case .firstRunStep, .createFirstBill: tabs.newBillTapped()
        case .importItems: tabs.showMore(.stock(.inventory(.bulkImport)))
        case .seePro: tabs.showMore(.settings(.plan))
        }
    }

    private func refreshSyncText() async {
        let engine = container.repositoryContainer.syncEngine
        if await engine.isSyncing {
            syncText = "Syncing"
        } else if await engine.failedCount > 0 {
            syncText = "Offline"
        } else if await engine.lastSuccessfulSync != nil {
            syncText = "Synced"
        }
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .storeSwitcher:
            StoreSwitcherView(session: session, salesByStore: viewModel.todaySalesByStore) {
                coordinator.dismissSheet()
                container.themeStore.apply(session: session)
                Task { await viewModel.load() }
            }
        case .firstRunGuide:
            ScreenFallback(title: "Welcome") {
                FirstRunGuideView(shopName: session.displayShopName, steps: viewModel.firstRunSteps,
                                  onStep: { handle(.firstRunStep($0.id)) },
                                  onCreateBill: { tabs.newBillTapped() },
                                  onImport: { handle(.importItems) })
            }
        case .planUsage:
            PlanLimitView(status: session.planStatus,
                          onUpgrade: { tabs.showMore(.settings(.plan)) },
                          onContinue: { coordinator.pop() },
                          onRemindTomorrow: { coordinator.pop() })
        case .openingBalances:
            OpeningBalancesView(viewModel: container.modulesContainer.makeOpeningBalancesViewModel(session: session)) {
                coordinator.popToRoot()
                Task { await viewModel.load() }
            }
        }
    }
}

/// Wraps a non-scrolling view in the standard screen chrome.
struct ScreenFallback<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView { content.padding() }
            .navigationTitle(title)
    }
}
