import SwiftUI
import ApoorvaModules
import ApoorvaModels

struct BillsCoordinatorView: View {
    let tabs: HomeTabsCoordinator
    @Bindable var coordinator: BillsCoordinator
    let container: AppContainer
    @State private var viewModel: BillsViewModel

    init(tabs: HomeTabsCoordinator, coordinator: BillsCoordinator, container: AppContainer) {
        self.tabs = tabs
        self.coordinator = coordinator
        self.container = container
        _viewModel = State(initialValue: container.modulesContainer.makeBillsViewModel())
    }

    private var session: AppSession { container.appSession }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            BillsListView(viewModel: viewModel,
                          onSelect: { sale in coordinator.push(.detail(billId: sale.id)) },
                          onFilters: { coordinator.presentFilters() })
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: BillsRoute.self) { route in
                    destination(for: route)
                }
        }
        .sheet(isPresented: $coordinator.isPresentingFilters) {
            NavigationStack {
                BillFiltersView(viewModel: viewModel, onClose: { coordinator.dismissFilters() })
            }
            .presentationDetents([.large])
        }
        .onChange(of: coordinator.path) { _, path in
            if path.isEmpty { Task { await viewModel.load() } }
        }
        .onChange(of: tabs.isPresentingNewBill) { _, isPresenting in
            if !isPresenting { Task { await viewModel.load() } }
        }
    }

    @ViewBuilder
    private func destination(for route: BillsRoute) -> some View {
        switch route {
        case .detail(let billId):
            BillDetailView(
                session: session,
                viewModel: container.modulesContainer.makeBillDetailViewModel(saleId: billId),
                onReprint: { sale in coordinator.push(.receiptPreview(billId: sale.id)) },
                onCancel: { sale in coordinator.push(.cancel(billId: sale.id)) },
                onEdit: { sale in coordinator.push(.edit(billId: sale.id)) },
                onReturn: { sale in
                    tabs.newBillCoordinator.path = [.returnExchange(billId: sale.id)]
                    tabs.newBillTapped()
                },
                onCollect: { sale in tabs.showCustomers(.collect(phone: sale.customerPhone)) },
                onLocked: { reason in tabs.showLocked(reason) }
            )
        case .cancel(let billId):
            Retained(container.modulesContainer.makeCancelBillViewModel(saleId: billId, actorId: session.actorId)) { viewModel in
                CancelBillView(viewModel: viewModel) { coordinator.pop() }
            }
        case .edit(let billId):
            Retained(container.modulesContainer.makeBillEditViewModel(saleId: billId, actorId: session.actorId)) { viewModel in
                BillEditView(viewModel: viewModel) { coordinator.pop() }
            }
        case .receiptPreview(let billId):
            Retained(container.modulesContainer.makeReceiptViewModel(saleId: billId, session: session)) { viewModel in
                ReceiptPreviewView(viewModel: viewModel, printerName: session.settings.receipt.printerName)
            }
        }
    }
}
