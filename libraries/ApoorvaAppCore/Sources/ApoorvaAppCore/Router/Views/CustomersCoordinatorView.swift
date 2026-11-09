import SwiftUI
import ApoorvaModules
import ApoorvaModels

struct CustomersCoordinatorView: View {
    let tabs: HomeTabsCoordinator
    @Bindable var coordinator: CustomersCoordinator
    let container: AppContainer
    @State private var listViewModel: CustomerListViewModel

    init(tabs: HomeTabsCoordinator, coordinator: CustomersCoordinator, container: AppContainer) {
        self.tabs = tabs
        self.coordinator = coordinator
        self.container = container
        self._listViewModel = State(initialValue: container.modulesContainer.makeCustomerListViewModel())
    }

    private var session: AppSession { container.appSession }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            CustomerListView(
                viewModel: listViewModel,
                onSelectCustomer: { customer in coordinator.push(.detail(phone: customer.phone)) },
                onAddCustomer: { coordinator.push(.add) },
                onImport: { coordinator.push(.importContacts) },
                onOffers: session.isOn(.offersMessages) ? { coordinator.push(.offers) } : nil
            )
            .navigationTitle("Customers")
            .navigationDestination(for: CustomersRoute.self) { route in
                destination(for: route)
            }
        }
        .onChange(of: coordinator.path) { _, path in
            if path.isEmpty { Task { await listViewModel.prepareDate() } }
        }
    }

    @ViewBuilder
    private func destination(for route: CustomersRoute) -> some View {
        switch route {
        case .detail(let phone):
            Retained(container.modulesContainer.makeCustomerDetailViewModel(phone: phone)) { viewModel in
                CustomerDetailView(
                    viewModel: viewModel,
                    canCollect: true,
                    onCollect: { coordinator.push(.collect(phone: phone)) },
                    onReminder: { coordinator.push(.reminder(phone: phone)) },
                    onStatement: { coordinator.push(.statement(phone: phone)) },
                    onEdit: { coordinator.push(.edit(phone: phone)) },
                    onNewBill: { customer in
                        tabs.startBill(with: PosCart(customerPhone: customer.phone, customerName: customer.name,
                                                     priceTier: customer.priceTier))
                    },
                    onBill: { saleId in tabs.showBill(saleId) }
                )
            }
        case .add:
            Retained(container.modulesContainer.makeCustomerFormViewModel(phone: nil)) { viewModel in
                CustomerFormView(viewModel: viewModel, showsCredit: session.isOn(.creditSales),
                                 showsWholesale: session.isOn(.wholesalePrice)) { customer in
                    coordinator.path = [.detail(phone: customer.phone)]
                }
            }
        case .edit(let phone):
            Retained(container.modulesContainer.makeCustomerFormViewModel(phone: phone)) { viewModel in
                CustomerFormView(viewModel: viewModel, showsCredit: session.isOn(.creditSales),
                                 showsWholesale: session.isOn(.wholesalePrice)) { _ in coordinator.pop() }
            }
        case .collect(let phone):
            Retained(container.modulesContainer.makeCollectDueViewModel(phone: phone, actorId: session.actorId)) { viewModel in
                CollectDueView(viewModel: viewModel) { coordinator.pop() }
            }
        case .reminder(let phone):
            Retained(container.modulesContainer.makeDueReminderViewModel(phone: phone, session: session)) { viewModel in
                DueReminderView(viewModel: viewModel) { coordinator.pop() }
            }
        case .statement(let phone):
            Retained(container.modulesContainer.makeStatementViewModel(phone: phone, session: session)) { viewModel in
                StatementView(viewModel: viewModel)
            }
        case .importContacts:
            Retained(container.modulesContainer.makeImportContactsViewModel()) { viewModel in
                ImportContactsView(viewModel: viewModel) { _ in coordinator.pop() }
            }
        case .offers:
            Retained(container.modulesContainer.makeOffersViewModel(session: session)) { viewModel in
                OffersView(viewModel: viewModel)
            }
        }
    }
}
