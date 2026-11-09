import SwiftUI
import ApoorvaModules
import ApoorvaModels

struct NewBillCoordinatorView: View {
    @Bindable var coordinator: NewBillCoordinator
    let container: AppContainer
    @Environment(\.dismiss) private var dismiss

    /// Created once per New Bill session (not inline in `body`) so the same cart
    /// survives every push/pop across the flow instead of resetting on redraw.
    @State private var posViewModel: POSViewModel
    /// Shared across `.checkout` and `.upiQR` — both routes act on the same in-progress
    /// sale, so they need the same view model instance, not a fresh one each push.
    @State private var checkoutViewModel: CheckoutViewModel?
    @State private var isShowingPlanLimit = false
    @State private var isPlanLimitAcknowledged = false

    init(coordinator: NewBillCoordinator, container: AppContainer) {
        self.coordinator = coordinator
        self.container = container
        self._posViewModel = State(initialValue: container.modulesContainer.makePOSViewModel())
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            POSView(
                viewModel: posViewModel,
                onPickCustomer: { coordinator.push(.customerPicker) },
                onAddItem: { category in coordinator.push(.lineEdit(itemId: category.id)) },
                onEditItem: { _, item in coordinator.push(.lineEdit(itemId: item.category.id)) },
                onOpenHeldBills: { coordinator.push(.held) },
                onCheckout: {
                    // Free plan past its limit: explain before billing (grace bills still go through).
                    if container.appSession.planStatus.isOverLimit && !isPlanLimitAcknowledged {
                        isShowingPlanLimit = true
                        return
                    }
                    openCheckout()
                }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: NewBillRoute.self) { route in
                destination(for: route)
            }
        }
        .sheet(isPresented: $isShowingPlanLimit) {
            NavigationStack {
                PlanLimitView(
                    status: container.appSession.planStatus,
                    onUpgrade: { isShowingPlanLimit = false; dismiss() },
                    onContinue: {
                        isShowingPlanLimit = false
                        isPlanLimitAcknowledged = true
                        openCheckout()
                    },
                    onRemindTomorrow: {
                        isShowingPlanLimit = false
                        isPlanLimitAcknowledged = true
                        openCheckout()
                    }
                )
            }
            .presentationDetents([.large])
        }
        .maniTheme(from: container.themeStore)
    }

    @ViewBuilder
    private func destination(for route: NewBillRoute) -> some View {
        switch route {
        case .verticalPicker:
            NotBuiltView(PlaceholderScreen("Vertical picker"))
        case .customerPicker:
            CustomerPickerView(
                viewModel: container.modulesContainer.makeCustomerPickerViewModel(),
                onSelect: { customer in
                    posViewModel.selectCustomer(customer)
                    coordinator.pop()
                }
            )
        case .lineEdit(let itemId):
            lineEditDestination(itemId: itemId)
        case .discount:
            NotBuiltView(PlaceholderScreen("Discount"))
        case .checkout:
            if let checkoutViewModel {
                CheckoutView(
                    viewModel: checkoutViewModel,
                    onRequireUPIConfirmation: { coordinator.push(.upiQR) },
                    onConfirmed: { sale in handleSaleConfirmed(sale) }
                )
            } else {
                NotBuiltView(PlaceholderScreen("Checkout"))
            }
        case .split:
            NotBuiltView(PlaceholderScreen("Split payment"))
        case .upiQR:
            if let checkoutViewModel {
                UPIQRView(
                    viewModel: checkoutViewModel,
                    onConfirmed: { sale in handleSaleConfirmed(sale) }
                )
            } else {
                NotBuiltView(PlaceholderScreen("UPI QR"))
            }
        case .receipt(let saleId):
            ReceiptView(
                viewModel: container.modulesContainer.makeReceiptViewModel(saleId: saleId),
                cameFromCheckout: true,
                onEditSale: { sale in
                    posViewModel.load(from: sale)
                    checkoutViewModel = nil
                    coordinator.popToRoot()
                },
                onDone: {
                    coordinator.popToRoot()
                    dismiss()
                },
                onUndo: container.appSession.can(.undoOwnBill) ? { sale in
                    Task {
                        _ = try? await container.repositoryContainer.saleLifecycleRepository.undo(
                            saleId: sale.id, by: container.appSession.actorId, now: Date())
                        posViewModel.load(from: sale)
                        coordinator.popToRoot()
                    }
                } : nil
            )
        case .held:
            HeldBillsView(
                viewModel: container.modulesContainer.makeHeldBillsViewModel(),
                onResume: { bill in
                    posViewModel.resume(heldBill: bill)
                    coordinator.popToRoot()
                }
            )
        case .returnExchange:
            NotBuiltView(PlaceholderScreen("Return / exchange"))
        case .scan:
            NotBuiltView(PlaceholderScreen("Scan"))
        case .receiptPreview:
            NotBuiltView(PlaceholderScreen("Receipt preview"))
        case .jewelItem:
            NotBuiltView(PlaceholderScreen("Design detail"))
        case .catalogShare:
            NotBuiltView(PlaceholderScreen("Share catalog"))
        case .parlourPackages:
            NotBuiltView(PlaceholderScreen("Packages"))
        }
    }

    private func openCheckout() {
        checkoutViewModel = container.modulesContainer.makeCheckoutViewModel(
            cart: posViewModel.cart,
            heldBillId: posViewModel.activeHeldBillId,
            session: container.appSession
        )
        coordinator.push(.checkout)
    }

    private func handleSaleConfirmed(_ sale: Sale) {
        posViewModel.clearCart()
        checkoutViewModel = nil
        coordinator.push(.receipt(saleId: sale.id))
    }

    @ViewBuilder
    private func lineEditDestination(itemId: String) -> some View {
        if let existing = posViewModel.cartItem(forCategoryId: itemId) {
            ItemPriceCalculatorView(
                viewModel: container.modulesContainer.makeItemPriceCalculatorViewModel(
                    category: existing.item.category,
                    existingItem: existing.item
                ),
                onSave: { item in
                    posViewModel.addOrUpdate(item)
                    coordinator.pop()
                }
            )
        } else if let category = category(forId: itemId) {
            ItemPriceCalculatorView(
                viewModel: container.modulesContainer.makeItemPriceCalculatorViewModel(
                    category: category,
                    existingItem: nil
                ),
                onSave: { item in
                    posViewModel.addOrUpdate(item)
                    coordinator.pop()
                }
            )
        } else {
            NotBuiltView(PlaceholderScreen("Item not found"))
        }
    }

    private func category(forId id: String) -> InventoryItem? {
        posViewModel.allCategories.first(where: { $0.id == id })
            ?? posViewModel.hotkeyItems.first(where: { $0.id == id })
    }
}
