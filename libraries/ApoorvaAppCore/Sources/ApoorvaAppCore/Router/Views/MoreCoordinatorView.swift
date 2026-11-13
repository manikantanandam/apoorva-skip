import SwiftUI
import ApoorvaModules
import ApoorvaModels
import ManiLogger

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
        case .cashflow: coordinator.push(.money(.cashflowDay(date: Date())))
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
        case .developer(let developerRoute):
            developerDestination(for: developerRoute)
        case .sell(let sellRoute):
            sellDestination(for: sellRoute)
        case .stock(.inventory(let inventoryRoute)):
            inventoryDestination(for: inventoryRoute)
        case .stock(let stockRoute):
            stockDestination(for: stockRoute)
        case .money(.transactions):
            CashflowTransactionListView(viewModel: container.modulesContainer.makeCashflowTransactionListViewModel())
        case .money(let moneyRoute):
            moneyDestination(for: moneyRoute)
        case .people(let peopleRoute):
            peopleDestination(for: peopleRoute)
        default:
            NotBuiltView(PlaceholderScreen(title(for: route)))
        }
    }

    @ViewBuilder
    private func sellDestination(for route: SellRoute) -> some View {
        switch route {
        case .orders:
            Retained(container.modulesContainer.makeOrdersViewModel()) { viewModel in
                OrdersListView(viewModel: viewModel,
                               onAdd: { coordinator.push(.sell(.orderAdd)) },
                               onSelect: { order in coordinator.push(.sell(.orderDetail(orderId: order.id))) })
            }
        case .orderAdd:
            Retained(container.modulesContainer.makeOrderFormViewModel(session: session)) { viewModel in
                OrderFormView(viewModel: viewModel) { order in
                    coordinator.pop()
                    coordinator.push(.sell(.orderDetail(orderId: order.id)))
                }
            }
        case .orderDetail(let orderId):
            Retained(container.modulesContainer.makeOrderDetailViewModel(orderId: orderId, session: session)) { viewModel in
                OrderDetailView(viewModel: viewModel) { cart in tabs.startBill(with: cart) }
            }
        case .heldBills:
            HeldBillsView(viewModel: container.modulesContainer.makeHeldBillsViewModel()) { bill in
                tabs.startBill(with: PosCart(items: bill.items,
                                             customerPhone: bill.customerPhone.isEmpty ? nil : bill.customerPhone,
                                             customerName: bill.customerName.isEmpty ? nil : bill.customerName),
                               heldBillId: bill.id)
            }
        case .warranty:
            Retained(container.modulesContainer.makeWarrantyViewModel(actorId: session.actorId)) { viewModel in
                WarrantyView(viewModel: viewModel)
            }
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
                canManageTeam: session.can(.admin),
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
        case .selectOrganization:
            OrganizationListView(viewModel: container.modulesContainer.makeOrganizationListViewModel())
        case .stores:
            // Store management isn't built yet. Keep it separate from organization selection.
            NotBuiltView(PlaceholderScreen(title(for: .admin(route))))
        case .members:
            UserListView(viewModel: container.modulesContainer.makeUserListViewModel())
        default:
            NotBuiltView(PlaceholderScreen(title(for: .admin(route))))
        }
    }

    @ViewBuilder
    private func inventoryDestination(for route: InventoryRoute) -> some View {
        let canEdit = session.can(.editInventory) && session.isOn(.inventoryEdit)
        switch route {
        case .list:
            Retained(container.modulesContainer.makeInventoryViewModel()) { viewModel in
                InventoryView(viewModel: viewModel,
                              onSelect: { item in coordinator.push(.stock(.inventory(.item(itemId: item.id)))) },
                              onAdd: canEdit ? { coordinator.push(.stock(.inventory(.add))) } : nil,
                              onMenu: { menu in
                                  switch menu {
                                  case .categories: coordinator.push(.stock(.inventory(.categories)))
                                  case .bulkImport: coordinator.push(.stock(.inventory(.bulkImport)))
                                  case .reorder: coordinator.push(.stock(.reorder))
                                  case .suppliers: coordinator.push(.stock(.suppliers))
                                  }
                              })
            }
        case .add:
            Retained(container.modulesContainer.makeItemFormViewModel(itemId: nil)) { viewModel in
                ItemFormView(viewModel: viewModel, showsWholesale: session.isOn(.wholesalePrice), showsWarranty: session.isOn(.warranty)) { item in
                    coordinator.pop()
                    coordinator.push(.stock(.inventory(.item(itemId: item.id))))
                }
            }
        case .edit(let itemId):
            Retained(container.modulesContainer.makeItemFormViewModel(itemId: itemId)) { viewModel in
                ItemFormView(viewModel: viewModel, showsWholesale: session.isOn(.wholesalePrice), showsWarranty: session.isOn(.warranty),
                             onSaved: { _ in coordinator.pop() },
                             onDeleted: { coordinator.path = [.stock(.inventory(.list))] })
            }
        case .item(let itemId):
            Retained(container.modulesContainer.makeInventoryItemViewModel(itemId: itemId)) { viewModel in
                InventoryItemView(viewModel: viewModel, canEdit: canEdit,
                                  onAdjust: { coordinator.push(.stock(.inventory(.adjust(itemId: itemId)))) },
                                  onEdit: { coordinator.push(.stock(.inventory(.edit(itemId: itemId)))) })
            }
        case .adjust(let itemId):
            Retained(container.modulesContainer.makeStockAdjustViewModel(itemId: itemId, actorId: session.actorId)) { viewModel in
                StockAdjustView(viewModel: viewModel) { coordinator.pop() }
            }
        case .categories:
            Retained(container.modulesContainer.makeCategoriesViewModel()) { viewModel in
                CategoriesView(viewModel: viewModel)
            }
        case .bulkImport:
            Retained(container.modulesContainer.makeItemImportViewModel()) { viewModel in
                ItemImportView(viewModel: viewModel) { _ in coordinator.pop() }
            }
        }
    }

    @ViewBuilder
    private func stockDestination(for route: StockRoute) -> some View {
        switch route {
        case .inventory(let inventoryRoute):
            inventoryDestination(for: inventoryRoute)
        case .suppliers:
            Retained(container.modulesContainer.makeSuppliersViewModel()) { viewModel in
                SuppliersView(viewModel: viewModel,
                              onAdd: { coordinator.push(.stock(.supplierAdd)) },
                              onSelect: { supplier in coordinator.push(.stock(.supplierDetail(supplierId: supplier.id))) })
            }
        case .supplierAdd:
            Retained(container.modulesContainer.makeSupplierFormViewModel()) { viewModel in
                SupplierFormView(viewModel: viewModel) { supplier in
                    coordinator.pop()
                    coordinator.push(.stock(.supplierDetail(supplierId: supplier.id)))
                }
            }
        case .supplierDetail(let supplierId):
            Retained(container.modulesContainer.makeSupplierDetailViewModel(supplierId: supplierId, actorId: session.actorId)) { viewModel in
                SupplierDetailView(viewModel: viewModel) { coordinator.push(.stock(.purchaseAdd(supplierId: supplierId))) }
            }
        case .purchaseAdd(let supplierId, let lines):
            Retained(container.modulesContainer.makePurchaseFormViewModel(supplierId: supplierId, lines: lines, actorId: session.actorId)) { viewModel in
                PurchaseFormView(viewModel: viewModel,
                                 onSaved: { _ in coordinator.pop() },
                                 onAddSupplier: { coordinator.push(.stock(.supplierAdd)) })
            }
        case .reorder:
            Retained(container.modulesContainer.makeReorderViewModel(session: session)) { viewModel in
                ReorderView(viewModel: viewModel) { supplierId, lines in
                    coordinator.push(.stock(.purchaseAdd(supplierId: supplierId, lines: lines)))
                }
            }
        }
    }

    @ViewBuilder
    private func moneyDestination(for route: MoneyRoute) -> some View {
        switch route {
        case .cashflowDay(let date):
            Retained(container.modulesContainer.makeCashDayViewModel(date: date)) { viewModel in
                CashDayView(viewModel: viewModel, canClose: session.can(.dayClose),
                            onAdd: { coordinator.push(.money(.cashflowAdd(date: date))) },
                            onClose: { coordinator.push(.money(.cashflowClose(date: date))) },
                            onHistory: { coordinator.push(.money(.cashflowHistory)) })
            }
        case .cashflowAdd:
            Retained(container.modulesContainer.makeCashEntryViewModel(actorId: session.actorId)) { viewModel in
                CashEntryView(viewModel: viewModel) { coordinator.pop() }
            }
        case .cashflowClose(let date):
            Retained(container.modulesContainer.makeDayCloseViewModel(date: date, session: session)) { viewModel in
                DayCloseView(viewModel: viewModel) {
                    coordinator.pop()
                    coordinator.push(.money(.dailySummary))
                }
            }
        case .cashflowHistory:
            Retained(container.modulesContainer.makeCashHistoryViewModel(actorId: session.actorId)) { viewModel in
                CashHistoryView(viewModel: viewModel, canReopen: session.can(.dayReopen)) { date in
                    coordinator.push(.money(.cashflowDay(date: date)))
                }
            }
        case .transactions:
            CashflowTransactionListView(viewModel: container.modulesContainer.makeCashflowTransactionListViewModel())
        case .expenses:
            Retained(container.modulesContainer.makeExpensesViewModel()) { viewModel in
                ExpensesView(viewModel: viewModel,
                             onAdd: { coordinator.push(.money(.expenseAdd(expenseId: nil))) },
                             onSelect: { expense in coordinator.push(.money(.expenseAdd(expenseId: expense.id))) })
            }
        case .expenseAdd(let expenseId):
            Retained(container.modulesContainer.makeExpenseFormViewModel(expenseId: expenseId, actorId: session.actorId)) { viewModel in
                ExpenseFormView(viewModel: viewModel) { coordinator.pop() }
            }
        case .dailySummary:
            Retained(container.modulesContainer.makeDailySummaryViewModel(session: session)) { viewModel in
                DailySummaryView(viewModel: viewModel)
            }
        case .insights(let insightsRoute):
            Retained(container.modulesContainer.makeInsightsViewModel(session: session)) { viewModel in
                InsightsView(viewModel: viewModel, tab: insightsTab(for: insightsRoute),
                             isServiceShop: session.vertical.billingStyle == .services,
                             canExport: session.can(.exportReports) && session.isOn(.insightsExport))
            }
        }
    }

    private func insightsTab(for route: InsightsRoute) -> InsightsTab {
        switch route {
        case .overview: .overview
        case .profit: .profit
        case .items: .items
        case .customers: .customers
        case .staff: .staff
        case .reports: .reports
        }
    }

    @ViewBuilder
    private func peopleDestination(for route: PeopleRoute) -> some View {
        switch route {
        case .staff:
            Retained(container.modulesContainer.makeInsightsViewModel(session: session)) { viewModel in
                InsightsView(viewModel: viewModel, tab: .staff, isServiceShop: session.vertical.billingStyle == .services,
                             canExport: session.can(.exportReports) && session.isOn(.insightsExport))
            }
        case .attendance:
            Retained(container.modulesContainer.makeAttendanceViewModel(actorId: session.actorId)) { viewModel in
                AttendanceView(viewModel: viewModel, canMark: session.can(.markAttendance))
            }
        case .salary:
            Retained(container.modulesContainer.makeSalaryViewModel(actorId: session.actorId)) { viewModel in
                SalaryView(viewModel: viewModel)
            }
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

// MARK: - Developer

extension MoreCoordinatorView {
    @ViewBuilder
    fileprivate func developerDestination(for route: DeveloperRoute) -> some View {
        switch route {
        case .hub:
            DeveloperHubRouteView(
                container: container,
                onOpenEnvironment: { coordinator.push(.developer(.environment)) },
                onOpenFlags: { coordinator.push(.developer(.flags)) },
                onOpenLogs: { coordinator.push(.developer(.logs)) }
            )
        case .environment:
            if let viewModel = container.makeDeveloperSettingsViewModel() {
                EnvironmentSwitchView(viewModel: viewModel)
            } else {
                NotBuiltView(PlaceholderScreen("Environment"))
            }
        case .flags:
            if let viewModel = container.makeFlagOverridesViewModel() {
                FlagOverridesView(viewModel: viewModel)
            } else {
                NotBuiltView(PlaceholderScreen("Feature flags"))
            }
        case .logs:
            if let viewModel = container.makeLogViewerViewModel() {
                LogViewerView(viewModel: viewModel)
            } else {
                NotBuiltView(PlaceholderScreen("Logs"))
            }
        }
    }
}

/// Holds the hub's view model so it isn't rebuilt each time the navigation destination re-evaluates.
private struct DeveloperHubRouteView: View {
    @State private var viewModel: DeveloperSettingsViewModel?
    let container: AppContainer
    let onOpenEnvironment: () -> Void
    let onOpenFlags: () -> Void
    let onOpenLogs: () -> Void

    var body: some View {
        if let viewModel {
            DeveloperSettingsView(viewModel: viewModel,
                                  onOpenEnvironment: onOpenEnvironment,
                                  onOpenFlags: onOpenFlags,
                                  onOpenLogs: onOpenLogs)
        } else {
            NotBuiltView(PlaceholderScreen("Developer"))
                .task { viewModel = container.makeDeveloperSettingsViewModel() }
        }
    }
}
