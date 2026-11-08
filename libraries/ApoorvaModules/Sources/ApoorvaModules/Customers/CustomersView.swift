//
//  CustomerListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

public struct CustomerListView: View {
    @Environment(\.maniTheme) private var theme

    @Bindable var viewModel: CustomerListViewModel

    @State private var isShowingFormatSheet = false
    @State private var selectedFormat: FileFormat?
    @State private var exportURL: URL?

    private let onSelectCustomer: (Customer) -> Void
    private let onAddCustomer: () -> Void

    public init(viewModel: CustomerListViewModel,
                onSelectCustomer: @escaping (Customer) -> Void,
                onAddCustomer: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSelectCustomer = onSelectCustomer
        self.onAddCustomer = onAddCustomer
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: ManiSpacing.md) {
                ManiSearchField(text: $viewModel.searchText, placeholder: "Search by name or phone")
                    .padding(.horizontal, ManiSpacing.lg)
                    .padding(.top, ManiSpacing.sm)

                if viewModel.filteredCustomers.isEmpty {
                    ManiNote("No customers found.", kind: .warning)
                        .padding(.horizontal, ManiSpacing.lg)
                        .padding(.top, ManiSpacing.lg)
                } else {
                    ForEach(viewModel.filteredCustomers) { item in
                        Button {
                            onSelectCustomer(item)
                        } label: {
                        ManiCard {
                            VStack(alignment: .leading, spacing: ManiSpacing.sm) {
                                HStack(spacing: ManiSpacing.sm) {
                                    ManiListRow(
                                        avatar: ManiAvatar(initials: initials(for: item.name)),
                                        title: item.name,
                                        subtitle: item.phone
                                    )
                                    Button(action: { call(item) }) {
                                        Image(systemName: "phone.fill")
                                            .foregroundStyle(theme.accent.accent)
                                    }
                                    .buttonStyle(.plain)
                                    Button(action: { onSelectCustomer(item) }) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .foregroundStyle(theme.base.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                }

                                Divider().overlay(theme.base.border)

                                ManiBreakdownRow(label: "Total Sales", value: "\(item.totalSales)")
                                ManiBreakdownRow(label: "Total Spent", value: "\(item.totalAmountSpent)")
                                ManiBreakdownRow(
                                    label: "Created Date",
                                    value: Date(timeIntervalSince1970: item.createdAt)
                                        .toString(format: "dd-MM-yyyy") ?? ""
                                )
                                if let lastPurchaseDate = item.lastPurchaseDate {
                                    ManiBreakdownRow(
                                        label: "Last Purchased Date",
                                        value: Date(timeIntervalSince1970: lastPurchaseDate)
                                            .toString(format: "dd-MM-yyyy") ?? ""
                                    )
                                } else {
                                    ManiBreakdownRow(label: "Last Purchased Date", value: "No purchase")
                                }
                            }
                        }
                        .padding(.horizontal, ManiSpacing.lg)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, ManiSpacing.lg)
        }
        .background(theme.base.background.ignoresSafeArea())
        .overlay(alignment: .bottomTrailing) {
            Button(action: onAddCustomer) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.accent.on)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(theme.accent.accent))
                    .shadow(radius: 4)
            }
            .padding(ManiSpacing.lg)
        }
        .toolbar{
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.forceSync()
                    }
                }) {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(CustomerSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        isShowingFormatSheet = true
                    }
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
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

    private func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        return String(trimmed.prefix(1)).uppercased()
    }

    private func call(_ customer: Customer) {
        guard !customer.phone.isEmpty, let url = URL(string: "tel://\(customer.phone)") else { return }
        UIApplication.shared.open(url)
    }
}

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
