//
//  CustomerPickerView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 08/11/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents
import ManiLogger

private let logger = AppLogger(category: .ui)

/// Customer for this bill (design 40).
public struct CustomerPickerView: View {
    @Bindable private var viewModel: CustomerPickerViewModel
    private let onSelect: (Customer?) -> Void

    private enum Field { case search, phone, name }
    // @State, not @FocusState: no `.focused($focus)` is attached here (the Mani fields own the real
    // FocusState and mirror it through a Binding<Bool>), so a FocusState would never invalidate the view.
    @State private var focus: Field?

    private func focusBinding(_ field: Field) -> Binding<Bool> {
        Binding(get: { focus == field }, set: { focus = $0 ? field : (focus == field ? nil : focus) })
    }

    public init(viewModel: CustomerPickerViewModel, onSelect: @escaping (Customer?) -> Void) {
        self.viewModel = viewModel
        self.onSelect = onSelect
    }

    private func subtitle(_ customer: Customer) -> String {
        if customer.dueBalance > 0 { return "\(customer.phone) · dues \(Money.format(customer.dueBalance))" }
        if let last = customer.lastPurchaseDate { return "\(customer.phone) · last visit \(Date(timeIntervalSince1970: last).shortDay)" }
        return customer.phone
    }

    public var body: some View {
        ScreenScroll {
            // Search/list/recent are hidden while typing a new customer so the form sits at the top above the keyboard.
            if focus == nil || focus == .search {
                ManiSearchField(text: $viewModel.searchText, placeholder: "Name or phone", focus: focusBinding(.search))
                if !viewModel.filteredCustomers.isEmpty {
                    RowsCard {
                        ForEach(viewModel.filteredCustomers.prefix(viewModel.searchText.isEmpty ? 8 : 30)) { customer in
                            ManiListRow(avatar: ManiAvatar(initials: String(customer.name.prefix(1))),
                                        title: customer.name, subtitle: subtitle(customer)) {
                                logger.info("Tapped customer row \(customer.id)")
                                onSelect(customer)
                            }
                        }
                    }
                }
                if viewModel.searchText.isEmpty && !viewModel.recent.isEmpty && focus == nil {
                    SectionHeader(title: "Recent")
                    FlowLayout {
                        ForEach(viewModel.recent) { customer in
                            ManiChip(customer.name) {
                                logger.info("Tapped recent chip \(customer.id)")
                                onSelect(customer)
                            }
                        }
                    }
                }
            }
            // While searching, only the search field and its results are shown.
            if focus != .search {
                SectionHeader(title: "New customer")
                ManiInputField(label: "Phone", text: $viewModel.newPhone, placeholder: "98480 55667",
                               focus: focusBinding(.phone), submitKind: .next) {
                    logger.info("Phone submitted, moving focus to Name")
                    focus = .name
                }
                ManiInputField(label: "Name", text: $viewModel.newName, placeholder: "Kiran",
                               focus: focusBinding(.name), submitKind: .done) {
                    logger.info("Name submitted, keyboard dismissed")
                    focus = nil
                }
                if let errorMessage = viewModel.errorMessage { ManiNote(errorMessage, kind: .error) }
            }
        } bottom: {
            // Hidden while typing: the pinned bar would otherwise ride above the keyboard and cover the fields.
            if focus == nil {
                VStack(spacing: ManiSpacing.sm) {
                    ManiButton("Add & attach", isEnabled: viewModel.canAdd) {
                        logger.info("Tapped Add & attach")
                        Task {
                            if let customer = await viewModel.addCustomer() {
                                logger.info("Attaching customer \(customer.id) to bill")
                                onSelect(customer)
                            }
                        }
                    }
                    ManiButton("Continue as walk-in", kind: .outline) {
                        logger.info("Tapped Continue as walk-in")
                        onSelect(nil)
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Customer for this bill")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            logger.info("Customer picker appeared")
            await viewModel.prepareData()
        }
        .onChange(of: focus) { _, new in
            logger.info("Focus: \(new.map { "\($0)" } ?? "none"), query length=\(viewModel.searchText.count), results=\(viewModel.filteredCustomers.count)")
        }
        .onChange(of: viewModel.searchText) { _, text in
            // A phone typed into search that matches nobody pre-fills the new customer's phone.
            if !text.isEmpty, text.allSatisfy(\.isNumber), viewModel.filteredCustomers.isEmpty { viewModel.newPhone = text }
        }
    }
}
