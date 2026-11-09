//
//  OpeningBalances.swift
//  ApoorvaModules
//
//  Design 17: dues and cash carried over from before the app.
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels
import ApoorvaRepository

public struct OpeningDue: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var name: String
    public var phone: String
    public var amount: Double
    public var isSupplier: Bool
}

@MainActor
@Observable
public final class OpeningBalancesViewModel {
    public var dues: [OpeningDue] = []
    public var cashInDrawer = ""
    public var draftName = ""
    public var draftPhone = ""
    public var draftAmount = ""
    public var draftIsSupplier = false
    public var isSaving = false
    public var errorMessage: String?

    private let session: AppSession
    private let customerRepository: CustomerRepositoryProtocol
    private let ledgerRepository: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>
    private let supplierRepository: any OrgCollectionRepositoryProtocol<Supplier>
    private let dailyCashflowRepository: DailyCashflowSummaryRepositoryProtocol
    private let organizationRepository: OrganizationRepositoryProtocol

    public init(session: AppSession,
                customerRepository: CustomerRepositoryProtocol,
                ledgerRepository: any OrgCollectionRepositoryProtocol<CustomerLedgerEntry>,
                supplierRepository: any OrgCollectionRepositoryProtocol<Supplier>,
                dailyCashflowRepository: DailyCashflowSummaryRepositoryProtocol,
                organizationRepository: OrganizationRepositoryProtocol) {
        self.session = session
        self.customerRepository = customerRepository
        self.ledgerRepository = ledgerRepository
        self.supplierRepository = supplierRepository
        self.dailyCashflowRepository = dailyCashflowRepository
        self.organizationRepository = organizationRepository
    }

    public var customersOwe: Double { dues.filter { !$0.isSupplier }.reduce(0) { $0 + $1.amount } }
    public var youOwe: Double { dues.filter(\.isSupplier).reduce(0) { $0 + $1.amount } }

    public var canAddDraft: Bool {
        !draftName.trimmingCharacters(in: .whitespaces).isEmpty && (Double(draftAmount) ?? 0) > 0
            && (draftIsSupplier || draftPhone.filter(\.isNumber).count >= 10)
    }

    public func startDraft(supplier: Bool) {
        draftIsSupplier = supplier
        draftName = ""
        draftPhone = ""
        draftAmount = ""
    }

    public func addDraft() {
        guard canAddDraft else { return }
        dues.append(OpeningDue(name: draftName.trimmingCharacters(in: .whitespaces),
                               phone: draftPhone.filter(\.isNumber),
                               amount: Double(draftAmount) ?? 0,
                               isSupplier: draftIsSupplier))
    }

    public func remove(_ due: OpeningDue) {
        dues.removeAll { $0.id == due.id }
    }

    /// Imports "name,phone,amount" lines (customers) from a CSV export.
    public func importCSV(_ text: String) -> Int {
        var added = 0
        for line in text.split(whereSeparator: \.isNewline).dropFirst() {
            let columns = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            guard columns.count >= 3, let amount = Double(columns[2]), amount > 0 else { continue }
            dues.append(OpeningDue(name: columns[0], phone: columns[1].filter(\.isNumber), amount: amount, isSupplier: false))
            added += 1
        }
        return added
    }

    public func save() async -> Bool {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let now = Date()
            for due in dues where !due.isSupplier {
                var customer = try await customerRepository.getCustomers().first { $0.phone == due.phone }
                    ?? Customer(name: due.name, phone: due.phone, createdAt: now.timeIntervalSince1970,
                                lastPurchaseDate: nil, totalSales: 0, totalAmountSpent: 0,
                                updatedAt: now.timeIntervalSince1970, isDeleted: false)
                customer.dueBalance += due.amount
                try await customerRepository.saveCustomer(customer: customer)
                try await ledgerRepository.save(CustomerLedgerEntry(
                    customerPhone: due.phone, customerName: due.name, kind: .opening, amount: due.amount,
                    note: "Opening balance", createdBy: session.actorId))
            }
            for due in dues where due.isSupplier {
                try await supplierRepository.save(Supplier(name: due.name, phone: due.phone, openingDue: due.amount))
            }
            if let cash = Double(cashInDrawer), cash > 0, let orgId = session.orgId {
                let accounts = (try? await organizationRepository.getOrganization(orgId: orgId))?.accounts ?? []
                let openings = accounts.map { AccountBalance(id: $0.id, name: $0.name, balance: $0.type == .cash ? cash : 0) }
                try await dailyCashflowRepository.saveDailyCashflowSummary(summary: DailyCashflowSummary(
                    date: Calendar.current.startOfDay(for: now), openingBalances: openings, closingBalances: [],
                    updatedAt: now.timeIntervalSince1970, locked: false))
            }
            try await session.saveSettings { $0.profile.openingBalancesSavedAt = now }
            return true
        } catch {
            errorMessage = "Couldn't save balances. Try again."
            return false
        }
    }
}

public struct OpeningBalancesView: View {
    @Bindable private var viewModel: OpeningBalancesViewModel
    @State private var isAddingDue = false
    @State private var isImporting = false
    private let onDone: () -> Void

    public init(viewModel: OpeningBalancesViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Bring over what's owed so your books start right")
            ManiStepIndicator(current: 4, total: 4)
            HStack(spacing: ManiSpacing.sm) {
                ManiKPITile(title: "Customers owe you", value: Money.format(viewModel.customersOwe), isHighlighted: true)
                ManiKPITile(title: "You owe suppliers", value: Money.format(viewModel.youOwe))
            }
            if !viewModel.dues.isEmpty {
                RowsCard {
                    ForEach(viewModel.dues) { due in
                        ManiListRow(avatar: ManiAvatar(initials: String(due.name.prefix(1))), title: due.name,
                                    subtitle: due.isSupplier ? "Supplier" : due.phone,
                                    value: Money.format(due.amount),
                                    status: (due.isSupplier ? "You owe" : "Due", due.isSupplier ? .warning : .neutral))
                            .contextMenu {
                                Button("Remove", role: .destructive) { viewModel.remove(due) }
                            }
                    }
                }
            }
            ManiInputField(label: "Cash in drawer today", text: $viewModel.cashInDrawer, placeholder: "₹0", keyboard: .decimal)
            FlowLayout {
                ManiChip("+ Customer due", icon: .customer) { viewModel.startDraft(supplier: false); isAddingDue = true }
                ManiChip("+ Supplier due", icon: .truck) { viewModel.startDraft(supplier: true); isAddingDue = true }
                ManiChip("Import Excel/CSV", icon: .upload) { isImporting = true }
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Save balances", isLoading: viewModel.isSaving) {
                    Task { if await viewModel.save() { onDone() } }
                }
                ManiButton("Skip for now", kind: .outline, action: onDone)
            }
        }
        .navigationTitle("Opening balances")
        .sheet(isPresented: $isAddingDue) {
            NavigationStack {
                ScreenScroll {
                    ManiInputField(label: viewModel.draftIsSupplier ? "Supplier name" : "Customer name", text: $viewModel.draftName)
                    ManiInputField(label: "Phone", text: $viewModel.draftPhone, keyboard: .phone)
                    ManiInputField(label: viewModel.draftIsSupplier ? "You owe" : "They owe", text: $viewModel.draftAmount,
                                   placeholder: "₹0", keyboard: .decimal)
                } bottom: {
                    ManiButton("Add", isEnabled: viewModel.canAddDraft) {
                        viewModel.addDraft()
                        isAddingDue = false
                    }
                }
                .navigationTitle(viewModel.draftIsSupplier ? "Supplier due" : "Customer due")
            }
            .presentationDetents([.medium])
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            if case .success(let url) = result, url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    _ = viewModel.importCSV(text)
                }
            }
        }
    }
}
