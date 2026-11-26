//
//  CustomerListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

/// Customers with dues filter (design 61).
public struct CustomerListView: View {
    @Environment(\.maniTheme) private var theme

    @Bindable var viewModel: CustomerListViewModel

    @AppStorage("customerList.showFullPhone") private var showFullPhone = true
    @State private var isShowingFormatSheet = false
    @State private var selectedFormat: FileFormat?
    @State private var exportURL: URL?

    private let onSelectCustomer: (Customer) -> Void
    private let onAddCustomer: () -> Void
    private let onImport: (() -> Void)?
    private let onOffers: (() -> Void)?

    public init(viewModel: CustomerListViewModel,
                onSelectCustomer: @escaping (Customer) -> Void,
                onAddCustomer: @escaping () -> Void,
                onImport: (() -> Void)? = nil,
                onOffers: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSelectCustomer = onSelectCustomer
        self.onAddCustomer = onAddCustomer
        self.onImport = onImport
        self.onOffers = onOffers
    }

    public var body: some View {
        ScreenScroll(spacing: ManiSpacing.md) {
            Button { viewModel.showDues() } label: {
                ScreenSubtitle(text: viewModel.subtitle)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.totalDue <= 0)
            ManiSearchField(text: $viewModel.searchText, placeholder: "Name or phone")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ManiSpacing.sm) {
                    ForEach(CustomerFilter.allCases, id: \.self) { filter in
                        ManiChip(filter.rawValue, isSelected: viewModel.filter == filter) { viewModel.filter = filter }
                    }
                }
            }
            if viewModel.filteredCustomers.isEmpty {
                ManiEmptyState(icon: .customers,
                               title: viewModel.customers.isEmpty ? "No customers yet" : "No match",
                               message: viewModel.customers.isEmpty ? "Customers are added when you bill them, or add one now." : nil,
                               actionTitle: viewModel.customers.isEmpty ? "Add customer" : nil,
                               action: viewModel.customers.isEmpty ? onAddCustomer : nil)
            } else {
                if viewModel.sort == .name {
                    ForEach(viewModel.alphabeticalSections, id: \.letter) { section in
                        Text(section.letter)
                            .font(theme.typography.secondary.weight(.semibold))
                            .foregroundStyle(theme.base.textSecondary)
                        RowsCard {
                            ForEach(section.customers) { row($0) }
                        }
                    }
                } else {
                    RowsCard {
                        ForEach(viewModel.filteredCustomers) { row($0) }
                    }
                }
            }
        }
        .refreshable { await viewModel.forceSync() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onAddCustomer) {
                    ManiSwiftUIComponents.IconView(.plus, size: 18, color: theme.base.text)
                }
                .accessibilityLabel("Add customer")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let onImport { Button("Import from contacts", action: onImport) }
                    if let onOffers { Button("Wishes & offers", action: onOffers) }
                    Picker("Sort by", selection: $viewModel.sort) {
                        ForEach(CustomerSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    Button(showFullPhone ? "Show last 4 digits" : "Show full numbers") { showFullPhone.toggle() }
                    Button("Export") { isShowingFormatSheet = true }
                    Button("Sync now") { Task { await viewModel.forceSync() } }
                } label: {
                    ManiSwiftUIComponents.IconView(.more, size: 18, color: theme.base.text)
                }
                .accessibilityIdentifier(AccessibilityID.Customers.moreMenu)
            }
        }
        .task {
            await viewModel.prepareDate()
        }
        // 2. Attach the sheet modifier
        .sheet(isPresented: $isShowingFormatSheet) {
            FormatSelectionSheet { format in
                selectedFormat = format
                isShowingFormatSheet = false
                if let url = try? viewModel.export(format: format) {
                    // Small delay ensures the current sheet dismisses cleanly
                    // before iOS triggers the native system share sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.exportURL = url
                    }
                }
            }
            // Sets the sheet to take up roughly half the screen on iOS 16+
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
                .presentationDetents([.medium, .large])
        }
    }

    private func row(_ item: Customer) -> some View {
        let visits = item.totalSales == 1 ? "1 visit" : "\(item.totalSales) visits"
        let phone = showFullPhone ? item.phone : item.maskedPhone
        let detail = item.totalSales > 0 ? "\(visits) · \(item.lastVisitText)" : item.lastVisitText
        let subtitle = "\(phone) · \(detail)"
        let value = item.totalAmountSpent > 0 ? Money.format(item.totalAmountSpent) : "—"
        let status = badge(for: item)
        // Spoken label starts with the name; the avatar initials would only add noise.
        let spoken = [item.name, subtitle, value, status?.0].compactMap { $0 }.joined(separator: ", ")
        return ManiListRow(avatar: ManiAvatar(initials: initials(for: item.name)),
                           title: item.name,
                           subtitle: subtitle,
                           value: value,
                           status: status) { onSelectCustomer(item) }
            .accessibilityLabel(Text(spoken))
            .contextMenu {
                Button("Call") { call(item) }
                Button("WhatsApp") { whatsApp(item) }
                Button("Copy number") { copy(item.phone) }
            }
    }

    private func badge(for item: Customer) -> (String, ManiStatusKind)? {
        if item.dueBalance > 0 { return ("\(Money.format(item.dueBalance)) due", .warning) }
        if item.isRegular { return ("Regular", .success) }
        if Date(timeIntervalSince1970: item.createdAt) >= (Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()) {
            return ("New", .neutral)
        }
        return nil
    }

    private func copy(_ text: String) {
        #if !os(Android)
        UIPasteboard.general.string = text
        #endif
    }

    private func whatsApp(_ customer: Customer) {
        let digits = customer.phone.filter(\.isNumber)
        guard !digits.isEmpty, let url = URL(string: "https://wa.me/\(digits.count == 10 ? "91" + digits : digits)") else { return }
        #if os(Android)
        Task { @MainActor in _ = await UIApplication.shared.open(url) }
        #else
        UIApplication.shared.open(url)
        #endif
    }

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(1)).uppercased()
    }

    private func call(_ customer: Customer) {
        guard !customer.phone.isEmpty, let url = URL(string: "tel://\(customer.phone)") else { return }
        #if os(Android)
        Task { @MainActor in _ = await UIApplication.shared.open(url) }
        #else
        UIApplication.shared.open(url)
        #endif
    }
}

#if os(Android)
/// Placeholder: there's no native share sheet in SkipSwiftUI yet, so Android shows nothing.
struct ShareSheet: View {
    var activityItems: [Any]

    var body: some View { EmptyView() }
}
#else
// 5. Lightweight UIViewControllerRepresentable helper to bring up the iOS Native Share UI
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// Extension to allow URL to safely bind to .sheet(item:)
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

// 3. The isolated Sheet View
struct FormatSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    var onSelect: (FileFormat) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Choose a format to proceed")) {
                    ForEach(FileFormat.allCases) { format in
                        ManiListRow(
                            title: format == .csv ? "Comma-Separated Values" : "vCard / Contacts",
                            subtitle: format.rawValue,
                            action: { onSelect(format) }
                        )
                    }
                }
            }
            .navigationTitle("Select Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
