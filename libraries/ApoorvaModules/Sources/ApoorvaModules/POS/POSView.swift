//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 07/10/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct POSView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: POSViewModel

    @State private var isShowingDatePicker = false

    private let onPickCustomer: () -> Void
    private let onAddItem: (InventoryItem) -> Void
    private let onEditItem: (Int, CartItem) -> Void
    private let onOpenHeldBills: () -> Void
    private let onCheckout: () -> Void

    public init(
        viewModel: POSViewModel,
        onPickCustomer: @escaping () -> Void,
        onAddItem: @escaping (InventoryItem) -> Void,
        onEditItem: @escaping (Int, CartItem) -> Void,
        onOpenHeldBills: @escaping () -> Void,
        onCheckout: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onPickCustomer = onPickCustomer
        self.onAddItem = onAddItem
        self.onEditItem = onEditItem
        self.onOpenHeldBills = onOpenHeldBills
        self.onCheckout = onCheckout
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: ManiSpacing.md) {
                HStack(alignment: .bottom, spacing: ManiSpacing.sm) {
                    VStack(spacing: ManiSpacing.md) {
                        ManiInputField(
                            label: "Customer name",
                            text: $viewModel.customerName,
                            placeholder: "e.g. Priya"
                        )

                        ManiInputField(
                            label: "Phone number",
                            text: $viewModel.customerPhoneNumber,
                            placeholder: "e.g. 98765 43210",
                            keyboard: .phone
                        )
                    }

                    Button(action: onPickCustomer) {
                        ManiSwiftUIComponents.IconView(.search, size: 18, color: theme.accent.accent)
                            .padding(ManiSpacing.sm)
                    }
                    .buttonStyle(.plain)
                }

                QuickItemsView(viewModel: viewModel) { category in
                    if let existing = viewModel.cartItem(forCategoryId: category.id) {
                        onEditItem(existing.index, existing.item)
                    } else {
                        onAddItem(category)
                    }
                }

                SelectedCartItemsView(viewModel: viewModel, onEditItem: onEditItem)

                Spacer()
            }
            .padding(ManiSpacing.lg)
        }
        .background(theme.base.background.ignoresSafeArea())
        .navigationTitle("New Bill")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { isShowingDatePicker = true }) {
                    ManiSwiftUIComponents.IconView(.calendar, size: 18, color: theme.base.text)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { Task { await viewModel.holdCurrentBill() } }) {
                    ManiSwiftUIComponents.IconView(.pause, size: 18, color: theme.base.text)
                }
                .disabled(viewModel.cart.items.isEmpty || viewModel.isHolding)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenHeldBills) {
                    ZStack(alignment: .topTrailing) {
                        ManiSwiftUIComponents.IconView(.tray, size: 18, color: theme.base.text)
                        if viewModel.heldBillsCount > 0 {
                            Text("\(viewModel.heldBillsCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(theme.accent.on)
                                .frame(width: 16, height: 16)
                                .background(theme.accent.accent)
                                .clipShape(Circle())
                                .offset(x: 8, y: -8)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingDatePicker) {
            NavigationStack {
                DatePicker("Bill date & time", selection: $viewModel.cart.billDateTime)
                    .datePickerStyle(.graphical)
                    .padding(ManiSpacing.lg)
                    .navigationTitle("Bill Date & Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isShowingDatePicker = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.cartItemCount > 0 {
                ManiActionBar(
                    summaryText: "\(viewModel.cartItemCount) items",
                    primaryTitle: "Proceed to checkout",
                    primaryAction: onCheckout,
                    secondaryTitle: "Hold bill",
                    secondaryAction: { Task { await viewModel.holdCurrentBill() } }
                )
                .padding(.horizontal, ManiSpacing.lg)
            }
        }
        .task {
            await viewModel.prepareData()
        }
    }
}
