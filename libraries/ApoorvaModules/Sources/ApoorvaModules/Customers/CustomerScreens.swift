//
//  CustomerScreens.swift
//  ApoorvaModules
//
//  Customer detail (62), add/edit (64), import (65), collect (66), reminder (67),
//  statement (68), wishes & offers (69).
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents
#if canImport(Contacts)
import Contacts
#endif

// MARK: - Detail (62)

public struct CustomerDetailView: View {
    @Environment(\.maniTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: CustomerDetailViewModel
    private let canCollect: Bool
    private let onCollect: () -> Void
    private let onReminder: () -> Void
    private let onStatement: () -> Void
    private let onEdit: () -> Void
    private let onNewBill: (Customer) -> Void
    private let onBill: (String) -> Void

    public init(viewModel: CustomerDetailViewModel, canCollect: Bool, onCollect: @escaping () -> Void,
                onReminder: @escaping () -> Void, onStatement: @escaping () -> Void, onEdit: @escaping () -> Void,
                onNewBill: @escaping (Customer) -> Void, onBill: @escaping (String) -> Void) {
        self.viewModel = viewModel
        self.canCollect = canCollect
        self.onCollect = onCollect
        self.onReminder = onReminder
        self.onStatement = onStatement
        self.onEdit = onEdit
        self.onNewBill = onNewBill
        self.onBill = onBill
    }

    private var due: Double { viewModel.customer?.dueBalance ?? 0 }

    public var body: some View {
        ScreenScroll {
            if let customer = viewModel.customer {
                ScreenSubtitle(text: "\(customer.phone) · since \(viewModel.since)")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: ManiSpacing.sm), GridItem(.flexible())], spacing: ManiSpacing.sm) {
                    ManiKPITile(title: "Balance due", value: Money.format(due), isHighlighted: due > 0)
                    ManiKPITile(title: "Lifetime", value: Money.format(viewModel.lifetime))
                    ManiKPITile(title: "Visits", value: "\(viewModel.visits)")
                    ManiKPITile(title: "Avg bill", value: Money.format(viewModel.averageBill))
                }
                if let since = viewModel.dueSince {
                    ScreenSubtitle(text: "Due since \(since.shortDay)")
                }
                if let notes = customer.notes, !notes.isEmpty { ManiNote(notes, kind: .info) }
                SectionHeader(title: "Ledger", actionTitle: "Statement", action: onStatement)
                if viewModel.rows.isEmpty {
                    ManiEmptyState(icon: .receipt, title: "No bills yet")
                } else {
                    RowsCard {
                        ForEach(viewModel.rows, id: \.id) { row in
                            ManiListRow(title: row.title, subtitle: row.subtitle, value: row.amount,
                                        status: row.status.map { ($0, row.isDue ? .warning : .success) }) {
                                if row.id.hasPrefix("bill-") { onBill(String(row.id.dropFirst(5))) }
                            }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        } bottom: {
            if let customer = viewModel.customer {
                VStack(spacing: ManiSpacing.sm) {
                    if due > 0 && canCollect { ManiButton("Collect due", icon: .cashIn, action: onCollect) }
                    ManiButton("New bill", icon: .plus, kind: due > 0 && canCollect ? .outline : .primary) { onNewBill(customer) }
                }
            }
        }
        .navigationTitle(viewModel.customer?.name ?? "Customer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit", action: onEdit)
                    if due > 0 { Button("Send reminder", action: onReminder) }
                    if let customer = viewModel.customer, let url = URL(string: "tel://\(customer.phone)") {
                        Button("Call") { openURL(url) }
                    }
                    Button("Statement", action: onStatement)
                } label: {
                    ManiSwiftUIComponents.IconView(.more, size: 18, color: theme.base.text)
                }
            }
        }
        .task { await viewModel.load() }
    }
}

// MARK: - Add / edit (64)

public struct CustomerFormView: View {
    @Bindable private var viewModel: CustomerFormViewModel
    private let showsCredit: Bool
    private let showsWholesale: Bool
    private let onSaved: (Customer) -> Void

    public init(viewModel: CustomerFormViewModel, showsCredit: Bool, showsWholesale: Bool, onSaved: @escaping (Customer) -> Void) {
        self.viewModel = viewModel
        self.showsCredit = showsCredit
        self.showsWholesale = showsWholesale
        self.onSaved = onSaved
    }

    public var body: some View {
        ScreenScroll {
            ManiInputField(label: "Name", text: $viewModel.name, placeholder: "Anitha Rao")
            ManiInputField(label: "Phone", text: $viewModel.phone, placeholder: "+91 97010 55443", keyboard: .phone)
                .disabled(viewModel.isEditing)
            ManiToggleRow(title: "Birthday (optional)", subtitle: viewModel.hasBirthday ? viewModel.birthday.formatted(.dateTime.day().month(.abbreviated)) : "For wishes and offers",
                          isOn: $viewModel.hasBirthday)
            if viewModel.hasBirthday {
                DatePicker("Birthday", selection: $viewModel.birthday, displayedComponents: .date)
            }
            ManiInputField(label: "Notes", text: $viewModel.notes, placeholder: "Prefers home delivery")
            RowsCard {
                ManiToggleRow(title: "WhatsApp receipts", subtitle: "Send bills on WhatsApp", isOn: $viewModel.whatsappReceipts)
                if showsCredit {
                    ManiToggleRow(title: "Allow credit", subtitle: viewModel.allowsCredit ? "Limit ₹\(viewModel.creditLimitText)" : "Bills must be paid in full",
                                  isOn: $viewModel.allowsCredit)
                }
                if showsWholesale {
                    ManiToggleRow(title: "Wholesale buyer", subtitle: "Always bill at wholesale prices", isOn: $viewModel.isWholesale)
                }
            }
            if showsCredit && viewModel.allowsCredit {
                ManiInputField(label: "Credit limit", text: $viewModel.creditLimitText, placeholder: "₹", keyboard: .number)
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Save customer", isLoading: viewModel.isSaving, isEnabled: viewModel.canSave) {
                Task { if let customer = await viewModel.save() { onSaved(customer) } }
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit customer" : "New customer")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - Collect (66)

public struct CollectDueView: View {
    @Bindable private var viewModel: CollectDueViewModel
    private let onDone: () -> Void

    public init(viewModel: CollectDueViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(viewModel.customer?.name ?? "") · due \(Money.format(viewModel.due))")
            ManiHeroAmount("₹" + (viewModel.amountText.isEmpty ? "0" : viewModel.amountText), caption: "of \(Money.format(viewModel.due)) due")
            FlowLayout {
                ForEach([PaymentMode.cash, .upi, .card], id: \.self) { mode in
                    ManiChip(mode.title, isSelected: viewModel.mode == mode) { viewModel.mode = mode }
                }
            }
            ManiKeypad { key in viewModel.amountText = key.apply(to: viewModel.amountText) }
            if viewModel.amount > viewModel.due && viewModel.due > 0 {
                ManiNote("That's more than the due. The extra isn't kept as credit.", kind: .warning)
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            ManiButton("Record \(Money.format(viewModel.amount)) payment", isLoading: viewModel.isSaving, isEnabled: viewModel.canRecord) {
                Task { if await viewModel.record() { onDone() } }
            }
        }
        .navigationTitle("Collect due")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - Reminder (67)

public struct DueReminderView: View {
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: DueReminderViewModel
    private let onSent: () -> Void

    public init(viewModel: DueReminderViewModel, onSent: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSent = onSent
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(viewModel.customer?.name ?? "") · due \(Money.format(viewModel.customer?.dueBalance ?? 0))")
            ManiSegmentedControl(selection: $viewModel.channel, options: DueReminderViewModel.Channel.allCases.map { ($0, $0.rawValue) })
            ManiNote(viewModel.message, kind: .info)
            ManiToggleRow(title: "Add UPI payment link",
                          subtitle: viewModel.canAddUPI ? "Customer pays in one tap" : "Add your UPI ID in Settings → Payments",
                          isOn: $viewModel.includesUPILink, isLocked: !viewModel.canAddUPI)
            ScreenSubtitle(text: "Messages are in English for now.")
        } bottom: {
            ManiButton("Send on \(viewModel.channel.rawValue)", icon: .message, isEnabled: viewModel.url != nil) {
                if let url = viewModel.url { openURL(url) }
                onSent()
            }
        }
        .navigationTitle("Send reminder")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - Statement (68)

public struct StatementView: View {
    @Environment(\.maniTheme) private var theme
    @Bindable private var viewModel: StatementViewModel
    @State private var format = Format.pdf
    @State private var exportURL: URL?

    enum Format: String, CaseIterable { case pdf = "PDF", image = "Image" }

    public init(viewModel: StatementViewModel) {
        self.viewModel = viewModel
    }

    private var rows: [ManiKeyValue] {
        let s = viewModel.statement
        return [ManiKeyValue("Opening balance", Money.format(s.opening)),
                ManiKeyValue("Bills", "+" + Money.format(s.bills)),
                ManiKeyValue("Payments", "−" + Money.format(s.payments)),
                ManiKeyValue("Closing balance", Money.format(s.closing))]
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: viewModel.customer?.name ?? viewModel.phone)
            FlowLayout {
                ForEach(StatementViewModel.Period.allCases, id: \.self) { period in
                    ManiChip(period.rawValue, isSelected: viewModel.period == period) { viewModel.period = period }
                }
            }
            if viewModel.period == .custom {
                DatePicker("From", selection: $viewModel.customStart, displayedComponents: .date)
                DatePicker("To", selection: $viewModel.customEnd, displayedComponents: .date)
            }
            ManiKeyValueSummary(rows: rows)
            ManiSegmentedControl(selection: $format, options: Format.allCases.map { ($0, $0.rawValue) })
            if !viewModel.statement.entries.isEmpty {
                RowsCard {
                    ForEach(viewModel.statement.entries) { entry in
                        ManiListRow(title: entry.note ?? entry.kind.rawValue.capitalized, subtitle: entry.createdAt.shortDay,
                                    value: (entry.amount >= 0 ? "+" : "−") + Money.format(abs(entry.amount)))
                    }
                }
            }
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Share on WhatsApp", icon: .share) { exportURL = render() }
                ShareLink(item: viewModel.shareText) {
                    Text("Share as text")
                        .font(theme.typography.body.weight(.semibold))
                        .foregroundStyle(theme.accent.accent)
                        .frame(maxWidth: .infinity, minHeight: ManiTouchTarget.minimum)
                }
            }
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
                .presentationDetents([.medium, .large])
        }
        .navigationTitle("Statement")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }

    /// Renders the statement card to a PDF or PNG in the temp folder.
    @MainActor private func render() -> URL? {
        let card = StatementCard(shopName: viewModel.shopName, customerName: viewModel.customer?.name ?? viewModel.phone,
                                 range: viewModel.range, statement: viewModel.statement)
            .frame(width: 360)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        let name = "Statement-\(viewModel.phone)"
        let folder = FileManager.default.temporaryDirectory
        if format == .image {
            guard let image = renderer.uiImage, let data = image.pngData() else { return nil }
            let url = folder.appendingPathComponent("\(name).png")
            return (try? data.write(to: url)) != nil ? url : nil
        }
        let url = folder.appendingPathComponent("\(name).pdf")
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
        }
        return url
    }
}

/// The printable statement (white paper, fixed colours so it reads the same in dark mode).
struct StatementCard: View {
    let shopName: String
    let customerName: String
    let range: (start: Date, end: Date)
    let statement: CustomerStatement

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(shopName).font(.headline)
            Text("Statement · \(customerName)").font(.subheadline)
            Text("\(range.start.shortDay) – \(range.end.shortDay)").font(.caption).foregroundStyle(.gray)
            Divider()
            line("Opening balance", Money.format(statement.opening))
            ForEach(statement.entries) { entry in
                line("\(entry.createdAt.shortDay)  \(entry.note ?? entry.kind.rawValue.capitalized)",
                     (entry.amount >= 0 ? "+" : "−") + Money.format(abs(entry.amount)))
            }
            Divider()
            line("Bills", "+" + Money.format(statement.bills))
            line("Payments", "−" + Money.format(statement.payments))
            line("Closing balance", Money.format(statement.closing)).bold()
        }
        .padding(20)
        .foregroundStyle(.black)
        .background(Color.white)
    }

    private func line(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left).font(.caption)
            Spacer()
            Text(right).font(.caption.monospacedDigit())
        }
    }
}

// MARK: - Import contacts (65)

public struct ImportContactsView: View {
    @Bindable private var viewModel: ImportContactsViewModel
    private let onDone: (Int) -> Void

    public init(viewModel: ImportContactsViewModel, onDone: @escaping (Int) -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    public var body: some View {
        ScreenScroll {
            if viewModel.isDenied {
                ManiEmptyState(icon: .people, title: "Contacts access is off",
                               message: "Allow Apoorva to read contacts in Settings → Privacy → Contacts.")
            } else {
                ScreenSubtitle(text: "Pick who to add · \(viewModel.selected.count) selected")
                ManiSearchField(text: $viewModel.searchText, placeholder: "Search contacts")
                if viewModel.contacts.isEmpty {
                    ManiEmptyState(icon: .people, title: "No new contacts", message: "Everyone with a mobile number is already a customer.")
                } else {
                    RowsCard {
                        ForEach(viewModel.visible) { contact in
                            ManiToggleRow(title: contact.name, subtitle: contact.phone,
                                          isOn: Binding(get: { viewModel.selected.contains(contact.id) },
                                                        set: { _ in viewModel.toggle(contact) }))
                        }
                    }
                }
                ScreenSubtitle(text: "Only names and numbers are imported")
                if let error = viewModel.errorMessage { ManiNote(error, kind: .warning) }
            }
        } bottom: {
            if !viewModel.isDenied {
                ManiButton("Add \(viewModel.selected.count) customers", isLoading: viewModel.isImporting,
                           isEnabled: !viewModel.selected.isEmpty) {
                    Task { onDone(await viewModel.importSelected()) }
                }
            }
        }
        .navigationTitle("Import contacts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

/// CNContactStore-backed contacts (iOS). Elsewhere it returns nothing.
public struct DeviceContactsProvider: ContactsProviding {
    public init() {}

    public func requestAccess() async -> Bool {
        #if canImport(Contacts)
        return (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        #else
        return false
        #endif
    }

    public func fetchContacts() async throws -> [PhoneContact] {
        #if canImport(Contacts)
        return try await Task.detached(priority: .userInitiated) {
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
            var result: [PhoneContact] = []
            try CNContactStore().enumerateContacts(with: CNContactFetchRequest(keysToFetch: keys)) { contact, _ in
                let name = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
                for (index, number) in contact.phoneNumbers.enumerated() where !name.isEmpty {
                    result.append(PhoneContact(id: "\(contact.identifier)#\(index)", name: name, phone: number.value.stringValue))
                }
            }
            return result
        }.value
        #else
        return []
        #endif
    }
}

// MARK: - Wishes & offers (69)

public struct OffersView: View {
    @Environment(\.maniTheme) private var theme
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: OffersViewModel

    public init(viewModel: OffersViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "WhatsApp · free to send")
            SectionHeader(title: "Birthdays today")
            if viewModel.birthdaysToday.isEmpty {
                ScreenSubtitle(text: "No birthdays today. Add birthdays on the customer page.")
            } else {
                RowsCard {
                    ForEach(viewModel.birthdaysToday) { customer in
                        ManiListRow(title: customer.name,
                                    subtitle: customer.isRegular ? "Regular · \(customer.totalSales) visits" : "\(customer.totalSales) visits",
                                    value: "Wish") {
                            if let url = viewModel.wishURL(for: customer) { openURL(url) }
                        }
                    }
                }
            }
            SectionHeader(title: "Send an offer")
            FlowLayout {
                ForEach(OffersViewModel.Audience.allCases, id: \.self) { audience in
                    ManiChip(audience.rawValue, isSelected: viewModel.audience == audience) { viewModel.audience = audience }
                }
            }
            TextEditor(text: $viewModel.message)
                .frame(minHeight: 110)
                .padding(ManiSpacing.sm)
                .background(theme.base.surface)
                .clipShape(RoundedRectangle(cornerRadius: theme.radii.card))
            ManiNote("WhatsApp doesn't allow bulk sends from apps. Share to a broadcast list of these \(viewModel.recipients.count) customers.", kind: .info)
        } bottom: {
            ShareLink(item: viewModel.message) {
                Text("Send to \(viewModel.recipients.count) \(viewModel.audience.rawValue.lowercased())")
                    .font(theme.typography.body.weight(.semibold))
                    .foregroundStyle(theme.accent.on)
                    .frame(maxWidth: .infinity, minHeight: ManiTouchTarget.minimum)
                    .background(viewModel.recipients.isEmpty ? theme.base.border : theme.accent.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.button))
            }
            .disabled(viewModel.recipients.isEmpty)
        }
        .navigationTitle("Wishes & offers")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}
