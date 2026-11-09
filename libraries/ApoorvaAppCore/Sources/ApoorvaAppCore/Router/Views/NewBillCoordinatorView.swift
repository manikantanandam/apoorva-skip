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
    /// Shared across checkout, split and UPI — they act on the same in-progress sale.
    @State private var checkoutViewModel: CheckoutViewModel?
    @State private var discountViewModel: BillDiscountViewModel?
    @State private var sheet: NewBillSheet?
    @State private var isShowingPlanLimit = false
    @State private var isPlanLimitAcknowledged = false
    @State private var isConfirmingClose = false
    /// Cash handed over for the last sale, for the receipt's "Change returned".
    @State private var lastCashReceived: Double?

    init(coordinator: NewBillCoordinator, container: AppContainer) {
        self.coordinator = coordinator
        self.container = container
        let posViewModel = container.modulesContainer.makePOSViewModel()
        // Started from elsewhere (customer page, order delivery, held bills): begin with that cart.
        // It's cleared on appear, not here, so the view's init stays free of state writes.
        if let cart = coordinator.pendingCart {
            posViewModel.cart = cart
            posViewModel.activeHeldBillId = coordinator.pendingHeldBillId
        }
        self._posViewModel = State(initialValue: posViewModel)
    }

    private var session: AppSession { container.appSession }

    private var config: POSConfig {
        POSConfig(style: session.vertical.billingStyle,
                  allowsCalculator: session.isOn(.calculatorMode),
                  allowsWholesale: session.isOn(.wholesalePrice),
                  tracksCommission: session.isOn(.staffCommission),
                  sellsPackages: session.isOn(.planPackages),
                  allowsHold: session.isOn(.holdBills),
                  counterName: [session.stores.count > 1 ? session.currentStore.name : nil, session.actorName]
                      .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            POSView(viewModel: posViewModel, config: config, onAction: handle)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            if posViewModel.cart.items.isEmpty { close() } else { isConfirmingClose = true }
                        }
                    }
                }
                .navigationDestination(for: NewBillRoute.self) { route in
                    destination(for: route)
                }
        }
        .sheet(item: $sheet) { sheet in
            NavigationStack { sheetContent(sheet) }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingPlanLimit) {
            NavigationStack {
                PlanLimitView(
                    status: session.planStatus,
                    onUpgrade: { isShowingPlanLimit = false; close() },
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
        .confirmationDialog("This bill isn't saved", isPresented: $isConfirmingClose, titleVisibility: .visible) {
            if config.allowsHold {
                Button("Hold bill") {
                    Task {
                        await posViewModel.holdCurrentBill()
                        close()
                    }
                }
            }
            Button("Discard bill", role: .destructive) { close() }
            Button("Keep billing", role: .cancel) {}
        }
        .maniTheme(from: container.themeStore)
        .onAppear {
            if coordinator.takePendingCart() != nil {
                Task { await posViewModel.reloadCustomer() }
            }
        }
    }

    private func close() {
        coordinator.popToRoot()
        dismiss()
    }

    // MARK: - POS actions

    private func handle(_ action: POSAction) {
        switch action {
        case .pickCustomer: coordinator.push(.customerPicker)
        case .openHeld: coordinator.push(.held)
        case .checkout:
            // Free plan past its limit: explain before billing (grace bills still go through).
            if session.planStatus.isOverLimit && !isPlanLimitAcknowledged {
                isShowingPlanLimit = true
            } else {
                openCheckout()
            }
        case .scan: coordinator.push(.scan)
        case .customItem: sheet = .customItem
        case .discount: openDiscount()
        case .packages: coordinator.push(.parlourPackages)
        case .catalogShare: coordinator.push(.catalogShare)
        case .editLine(let lineId): coordinator.push(.lineEdit(lineId: lineId))
        case .newLine(let itemId): coordinator.push(.newLine(itemId: itemId))
        case .weigh(let itemId): sheet = .weight(itemId: itemId)
        case .variant(let itemId): sheet = .variant(itemId: itemId)
        case .itemDetail(let itemId): coordinator.push(.jewelItem(itemId: itemId))
        }
    }

    private func openDiscount() {
        Task {
            discountViewModel = await container.modulesContainer.makeBillDiscountViewModel(cart: posViewModel.cart, session: session)
            sheet = .discount
        }
    }

    private func openCheckout() {
        checkoutViewModel = container.modulesContainer.makeCheckoutViewModel(
            cart: posViewModel.cart,
            heldBillId: posViewModel.activeHeldBillId,
            session: session
        )
        coordinator.push(.checkout)
    }

    private func handleSaleConfirmed(_ sale: Sale) {
        lastCashReceived = checkoutViewModel?.cashReceived
        posViewModel.clearCart()
        checkoutViewModel = nil
        coordinator.path = [.receipt(saleId: sale.id)]
        Task {
            await container.modulesContainer.recordPackagePurchases(in: sale)
            await container.modulesContainer.markOrdersDelivered(in: sale)
        }
    }

    private var customerSubtitle: String? {
        guard let customer = posViewModel.customer else { return nil }
        return customer.dueBalance > 0 ? "\(customer.phone) · dues \(Money.format(customer.dueBalance))" : customer.phone
    }

    // MARK: - Routes

    @ViewBuilder
    private func destination(for route: NewBillRoute) -> some View {
        switch route {
        case .customerPicker:
            CustomerPickerView(
                viewModel: container.modulesContainer.makeCustomerPickerViewModel(),
                onSelect: { customer in
                    posViewModel.selectCustomer(customer)
                    checkoutViewModel?.cart.customerName = customer?.name
                    checkoutViewModel?.cart.customerPhone = customer?.phone
                    coordinator.pop()
                }
            )
        case .lineEdit(let lineId):
            if let line = posViewModel.line(id: lineId) {
                Retained(container.modulesContainer.makeLineEditViewModel(line: line, isNew: false)) { viewModel in
                    LineEditView(viewModel: viewModel, showsWarranty: session.isOn(.warranty),
                                 onSave: { item in
                                     posViewModel.addOrUpdate(item)
                                     coordinator.pop()
                                 },
                                 onRemove: {
                                     posViewModel.removeLine(id: lineId)
                                     coordinator.pop()
                                 })
                }
            } else {
                ManiMissingView(title: "Line removed")
            }
        case .newLine(let itemId):
            if let item = posViewModel.item(id: itemId) {
                Retained(container.modulesContainer.makeLineEditViewModel(
                    line: CartItem(category: item, mrp: posViewModel.price(of: item) ?? 0, quantity: 1,
                                   warrantyMonths: item.warrantyMonths, lineId: UUID().uuidString),
                    isNew: true)) { viewModel in
                    LineEditView(viewModel: viewModel, showsWarranty: session.isOn(.warranty),
                                 onSave: { line in
                                     posViewModel.addOrUpdate(line)
                                     coordinator.pop()
                                 },
                                 onRemove: { coordinator.pop() })
                }
            } else {
                ManiMissingView(title: "Item not found")
            }
        case .checkout:
            if let checkoutViewModel {
                CheckoutView(
                    viewModel: checkoutViewModel,
                    customerSubtitle: customerSubtitle,
                    onChangeCustomer: { coordinator.push(.customerPicker) },
                    onSplit: { coordinator.push(.split) },
                    onRequireUPIConfirmation: { coordinator.push(.upiQR) },
                    onHold: config.allowsHold ? {
                        Task {
                            await posViewModel.holdCurrentBill()
                            self.checkoutViewModel = nil
                            coordinator.popToRoot()
                        }
                    } : nil,
                    onConfirmed: handleSaleConfirmed
                )
            } else {
                ManiMissingView(title: "Checkout closed")
            }
        case .split:
            if let checkoutViewModel {
                SplitPaymentView(viewModel: checkoutViewModel, onConfirmed: handleSaleConfirmed)
            } else {
                ManiMissingView(title: "Checkout closed")
            }
        case .upiQR:
            if let checkoutViewModel {
                UPIQRView(viewModel: checkoutViewModel,
                          onChangeMode: { coordinator.pop() },
                          onConfirmed: handleSaleConfirmed)
            } else {
                ManiMissingView(title: "Checkout closed")
            }
        case .receipt(let saleId):
            Retained(container.modulesContainer.makeReceiptViewModel(saleId: saleId, session: session, cashReceived: lastCashReceived)) { viewModel in
                ReceiptView(
                    viewModel: viewModel,
                    cameFromCheckout: true,
                    onEditSale: { sale in
                        posViewModel.load(from: sale)
                        coordinator.popToRoot()
                    },
                    onDone: close,
                    onUndo: session.can(.undoOwnBill) ? { sale in
                        Task {
                            _ = try? await container.repositoryContainer.saleLifecycleRepository.undo(
                                saleId: sale.id, by: session.actorId, now: Date())
                            await session.refreshPlanUsage()
                            posViewModel.load(from: sale)
                            coordinator.popToRoot()
                        }
                    } : nil,
                    onNewBill: { coordinator.popToRoot() },
                    onPreview: { sale in coordinator.push(.receiptPreview(saleId: sale.id)) }
                )
            }
        case .receiptPreview(let saleId):
            Retained(container.modulesContainer.makeReceiptViewModel(saleId: saleId, session: session)) { viewModel in
                ReceiptPreviewView(viewModel: viewModel, printerName: session.settings.receipt.printerName)
            }
        case .held:
            HeldBillsView(
                viewModel: container.modulesContainer.makeHeldBillsViewModel(),
                onResume: { bill in
                    posViewModel.resume(heldBill: bill)
                    coordinator.popToRoot()
                }
            )
        case .returnExchange(let billId):
            Retained(container.modulesContainer.makeReturnViewModel(saleId: billId, session: session)) { viewModel in
                ReturnView(viewModel: viewModel,
                           onReturned: { sale in coordinator.path = [.receipt(saleId: sale.id)] },
                           onExchange: { cart in
                               posViewModel.clearCart()
                               posViewModel.cart = cart
                               Task { await posViewModel.reloadCustomer() }
                               coordinator.popToRoot()
                           })
            }
        case .scan:
            ScanView(viewModel: posViewModel, onDone: { coordinator.pop() })
        case .jewelItem(let itemId):
            if let item = posViewModel.item(id: itemId) {
                JewelItemView(item: item, price: posViewModel.price(of: item),
                              similar: posViewModel.items.filter { $0.id != item.id && $0.categoryId == item.categoryId && item.categoryId != nil }
                                  .prefix(6).map { $0 },
                              onAdd: {
                                  if case .added = posViewModel.tap(item) {
                                      coordinator.pop()
                                  } else {
                                      coordinator.path[coordinator.path.count - 1] = .newLine(itemId: item.id)
                                  }
                              },
                              onOpen: { other in coordinator.push(.jewelItem(itemId: other.id)) })
            } else {
                ManiMissingView(title: "Design not found")
            }
        case .catalogShare:
            CatalogShareView(items: posViewModel.items, categoryNames: posViewModel.categoryNames)
        case .parlourPackages:
            Retained(container.modulesContainer.makePackagesViewModel(customerPhone: posViewModel.cart.customerPhone,
                                                                      customerName: posViewModel.cart.customerName ?? "")) { viewModel in
                PackagesView(viewModel: viewModel,
                             onSell: { line in
                                 posViewModel.addOrUpdate(line)
                                 coordinator.pop()
                             },
                             onUsed: { coordinator.pop() })
            }
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: NewBillSheet) -> some View {
        switch sheet {
        case .weight(let itemId):
            if let item = posViewModel.item(id: itemId) {
                WeightSheet(item: item, pricePerUnit: posViewModel.price(of: item)) { weight, price in
                    posViewModel.addWeighted(item, weight: weight, pricePerUnit: price)
                    self.sheet = nil
                }
                .toolbar { closeButton }
            }
        case .customItem:
            CustomItemSheet { name, amount, category, save in
                Task {
                    await posViewModel.addCustom(name: name, amount: amount, category: category, saveAsItem: save)
                    self.sheet = nil
                }
            }
            .toolbar { closeButton }
        case .variant(let itemId):
            if let item = posViewModel.item(id: itemId), let variants = ItemVariants.from(item) {
                VariantSheet(item: item, variants: variants, price: posViewModel.price(of: item) ?? 0) { variant, quantity in
                    posViewModel.addVariant(item, variant: variant, quantity: quantity)
                    self.sheet = nil
                }
                .toolbar { closeButton }
            }
        case .discount:
            if let discountViewModel {
                BillDiscountView(viewModel: discountViewModel) { amount, percent in
                    posViewModel.applyDiscount(amount: amount, percent: percent)
                    self.sheet = nil
                }
                .toolbar { closeButton }
            }
        }
    }

    @ToolbarContentBuilder private var closeButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { sheet = nil }
        }
    }
}

/// Shown if a route outlives its data (e.g. a line removed while its editor was open).
private struct ManiMissingView: View {
    let title: String

    var body: some View {
        NotBuiltView(PlaceholderScreen(title))
    }
}
