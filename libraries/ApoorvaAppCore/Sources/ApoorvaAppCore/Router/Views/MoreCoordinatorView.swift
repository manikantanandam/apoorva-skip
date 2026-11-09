import SwiftUI
import ApoorvaModules
import ApoorvaModels

struct MoreCoordinatorView: View {
    let tabs: HomeTabsCoordinator
    @Bindable var coordinator: MoreCoordinator
    let container: AppContainer
    @State private var counts = MoreMenuCounts()
    @State private var memberCount = 0
    @State private var lastSync: Date?
    @State private var isSwitchingStaff = false

    private var session: AppSession { container.appSession }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            MoreMenuView(
                session: session,
                counts: counts,
                showsDeveloper: container.showsDeveloperTools,
                onSelect: select,
                onSearch: { tabs.present(.search) }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MoreRoute.self) { route in
                destination(for: route)
            }
            .task { await loadCounts() }
        }
        .sheet(item: $coordinator.presentedSheet) { route in
            NavigationStack {
                destination(for: route)
            }
        }
        .sheet(isPresented: $isSwitchingStaff) {
            NavigationStack {
                PinSwitchView(viewModel: container.modulesContainer.makePinSwitchViewModel(session: session),
                              onSwitched: { isSwitchingStaff = false })
            }
        }
    }

    private func select(_ item: MoreMenuItem) {
        switch item {
        case .orders: coordinator.push(.sell(.orders))
        case .heldBills: coordinator.push(.sell(.heldBills))
        case .warranty: coordinator.push(.sell(.warranty))
        case .inventory: coordinator.push(.stock(.inventory(.list)))
        case .suppliers: coordinator.push(.stock(.suppliers))
        case .reorder: coordinator.push(.stock(.reorder))
        case .cashflow: coordinator.push(.money(.cashflowHistory))
        case .expenses: coordinator.push(.money(.expenses))
        case .summary: coordinator.push(.money(.dailySummary))
        case .insights: coordinator.push(.money(.insights(.overview)))
        case .staff: coordinator.push(.people(.staff))
        case .attendance: coordinator.push(.people(.attendance))
        case .salary: coordinator.push(.people(.salary))
        case .settings: coordinator.push(.settings(.hub))
        case .admin: coordinator.push(.admin(.home))
        case .console: coordinator.push(.console(.home))
        case .help: tabs.present(.help)
        case .developer: coordinator.push(.developer(.hub))
        case .switchStaff: isSwitchingStaff = true
        case .exitDemo: Task { await tabs.appCoordinator?.exitDemo() }
        }
    }

    private func loadCounts() async {
        let repositories = container.repositoryContainer
        let heldBills = (try? await repositories.heldBillRepository.getHeldBills().count) ?? 0
        let lowStock = (try? await repositories.inventoryRepository.getInventoryItems().filter(\.isLowStock).count) ?? 0
        counts = MoreMenuCounts(heldBills: heldBills, reorder: lowStock)
        memberCount = (try? await repositories.memberRepository.all().count) ?? 0
        lastSync = await repositories.syncEngine.lastSuccessfulSync
    }

    @ViewBuilder
    private func destination(for route: MoreRoute) -> some View {
        switch route {
        case .settings(let settingsRoute):
            settingsDestination(for: settingsRoute)
        case .admin(let adminRoute):
            adminDestination(for: adminRoute)
        case .developer(.hub):
            if let developerViewModel = container.makeDeveloperSettingsViewModel() {
                DeveloperSettingsView(viewModel: developerViewModel)
            } else {
                NotBuiltView(PlaceholderScreen("Developer"))
            }
        case .stock(.inventory(let inventoryRoute)):
            inventoryDestination(for: inventoryRoute)
        case .money(.cashflowHistory):
            DailyCashflowListView(
                viewModel: container.modulesContainer.makeDailyCashflowListViewModel(),
                onSelectDate: { date in coordinator.push(.money(.cashflowDay(date: date))) }
            )
        case .money(.cashflowDay(let date)):
            DailyCashFlowView(
                viewModel: container.modulesContainer.makeDailyCashflowViewModel(selectedDate: date),
                makeAddUpdateSummaryViewModel: { date, summary in
                    container.modulesContainer.makeAddUpdateDailyCashflowViewModel(existingSummary: summary, date: date)
                },
                makeAddUpdateTransactionViewModel: { date, transaction in
                    container.modulesContainer.makeAddUpdateCashflowTransactionViewModel(existingTransaction: transaction, defaultDate: date)
                }
            )
        case .money(.transactions):
            CashflowTransactionListView(viewModel: container.modulesContainer.makeCashflowTransactionListViewModel())
        default:
            NotBuiltView(PlaceholderScreen(title(for: route)))
        }
    }

    @ViewBuilder
    private func settingsDestination(for route: SettingsRoute) -> some View {
        switch route {
        case .hub:
            SettingsHubView(session: session) { item in
                coordinator.push(.settings(settingsRoute(for: item)))
            }
        case .appearance:
            AppearanceView(session: session, themeStore: container.themeStore)
        case .account:
            ProfileView(
                viewModel: container.modulesContainer.makeProfileViewModel(),
                onSelectOrganization: { coordinator.present(.admin(.selectOrganization)) },
                onShowOrganizations: { coordinator.push(.admin(.stores)) },
                onShowTeamMembers: { coordinator.push(.admin(.members)) },
                onShowDeveloperSettings: container.showsDeveloperTools ? { coordinator.push(.developer(.hub)) } : nil
            )
        default:
            NotBuiltView(PlaceholderScreen(title(for: .settings(route))))
        }
    }

    private func settingsRoute(for item: SettingsItem) -> SettingsRoute {
        switch item {
        case .appearance: .appearance
        case .tax: .tax
        case .receipts: .receipts
        case .payments: .payments
        case .printer: .printer
        case .language: .language
        case .backup: .backup
        case .account: .account
        case .plan: .plan
        case .devices: .devices
        case .signInMethods: .signInMethods
        }
    }

    @ViewBuilder
    private func adminDestination(for route: AdminRoute) -> some View {
        switch route {
        case .home:
            AdminHomeView(session: session, memberCount: memberCount, lastSync: lastSync) { item in
                switch item {
                case .stores: coordinator.push(.admin(.stores))
                case .members: coordinator.push(.admin(.members))
                case .permissions: coordinator.push(.admin(.permissions))
                case .theme: coordinator.push(.admin(.theme))
                case .features: coordinator.push(.admin(.features))
                case .audit: coordinator.push(.admin(.audit))
                case .invite: coordinator.push(.admin(.invite))
                }
            }
        case .stores, .selectOrganization:
            OrganizationListView(viewModel: container.modulesContainer.makeOrganizationListViewModel())
        case .members:
            UserListView(viewModel: container.modulesContainer.makeUserListViewModel())
        default:
            NotBuiltView(PlaceholderScreen(title(for: .admin(route))))
        }
    }

    @ViewBuilder
    private func inventoryDestination(for route: InventoryRoute) -> some View {
        switch route {
        case .list:
            InventoryView(viewModel: container.modulesContainer.makeInventoryViewModel())
        case .add, .edit:
            NotBuiltView(PlaceholderScreen("Add inventory item"))
        case .item:
            NotBuiltView(PlaceholderScreen("Inventory item"))
        case .adjust:
            NotBuiltView(PlaceholderScreen("Adjust stock"))
        case .categories:
            NotBuiltView(PlaceholderScreen("Inventory categories"))
        case .bulkImport:
            NotBuiltView(PlaceholderScreen("Bulk import"))
        }
    }

    private func title(for route: MoreRoute) -> String {
        switch route {
        case .sell(let r): return "\(r)".capitalized
        case .stock(let r): return "\(r)".capitalized
        case .money(let r): return "\(r)".capitalized
        case .people(let r): return "\(r)".capitalized
        case .settings(let r): return "\(r)".capitalized
        case .admin(let r): return "\(r)".capitalized
        case .console(let r): return "\(r)".capitalized
        case .developer(let r): return "\(r)".capitalized
        case .help: return "Help"
        }
    }
}
