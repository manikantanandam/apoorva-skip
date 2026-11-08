import SwiftUI
import ApoorvaModules

struct MoreCoordinatorView: View {
    @Bindable var coordinator: MoreCoordinator
    let container: AppContainer

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            MoreMenuView(coordinator: coordinator)
                .navigationTitle("More")
                .navigationDestination(for: MoreRoute.self) { route in
                    destination(for: route)
                }
        }
        .sheet(item: $coordinator.presentedSheet) { route in
            NavigationStack {
                destination(for: route)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: MoreRoute) -> some View {
        switch route {
        case .settings(.account):
            ProfileView(
                viewModel: container.modulesContainer.makeProfileViewModel(),
                onSelectOrganization: { coordinator.present(.admin(.selectOrganization)) },
                onShowOrganizations: { coordinator.push(.admin(.stores)) },
                onShowTeamMembers: { coordinator.push(.admin(.members)) },
                onShowDeveloperSettings: container.makeDeveloperSettingsViewModel() != nil
                    ? { coordinator.push(.developer(.hub)) }
                    : nil
            )
        case .admin(.stores), .admin(.selectOrganization):
            OrganizationListView(viewModel: container.modulesContainer.makeOrganizationListViewModel())
        case .admin(.members):
            UserListView(viewModel: container.modulesContainer.makeUserListViewModel())
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
    private func inventoryDestination(for route: InventoryRoute) -> some View {
        switch route {
        case .list:
            InventoryView(viewModel: container.modulesContainer.makeInventoryViewModel())
        case .add:
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

struct MoreMenuView: View {
    @Bindable var coordinator: MoreCoordinator

    var body: some View {
        List {
            Section("Sell") {
                row("Orders") { coordinator.push(.sell(.orders)) }
                row("Held bills") { coordinator.push(.sell(.heldBills)) }
                row("Warranty") { coordinator.push(.sell(.warranty)) }
            }
            Section("Stock") {
                row("Inventory") { coordinator.push(.stock(.inventory(.list))) }
                row("Suppliers") { coordinator.push(.stock(.suppliers)) }
                row("Reorder") { coordinator.push(.stock(.reorder)) }
            }
            Section("Money") {
                row("Cashflow") { coordinator.push(.money(.cashflowHistory)) }
                row("Expenses") { coordinator.push(.money(.expenses)) }
                row("Summary") { coordinator.push(.money(.dailySummary)) }
                row("Insights") { coordinator.push(.money(.insights)) }
            }
            Section("People") {
                row("Staff") { coordinator.push(.people(.staff)) }
                row("Attendance") { coordinator.push(.people(.attendance)) }
                row("Salary") { coordinator.push(.people(.salary)) }
            }
            Section {
                row("Settings") { coordinator.push(.settings(.account)) }
                row("Admin") { coordinator.push(.admin(.stores)) }
                row("Apoorva Console") { coordinator.push(.console(.home)) }
                row("Help") { coordinator.push(.help) }
                row("Developer") { coordinator.push(.developer(.hub)) }
            }
        }
    }

    private func row(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
}
