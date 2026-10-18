// AddUpdateDailyCashflowSummaryView.swift
import SwiftUI
import ApoorvaModels

public struct AddUpdateDailyCashflowSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddUpdateDailyCashflowSummaryViewModel
    
    public init(viewModel: AddUpdateDailyCashflowSummaryViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Date Section
                    ModernFormCard(title: "Summary Date") {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.blue)
                                .font(.title3)
                            
                            DatePicker("Select Date", selection: $viewModel.date, displayedComponents: .date)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            Spacer()
                        }
                    }
                    
                    // MARK: - Opening Balances
                    if !viewModel.accounts.isEmpty {
                        ModernFormCard(title: "Opening Balance") {
                            VStack(spacing: 12) {
                                ForEach(viewModel.accounts, id: \.id) { account in
                                    AccountBalanceInputRow(
                                        accountName: account.name,
                                        text: bindingForOpening(accountId: account.id)
                                    )
                                    if account.id != viewModel.accounts.last?.id {
                                        Divider().opacity(0.5)
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Closing Balances
                        ModernFormCard(title: "Closing Balance") {
                            VStack(spacing: 12) {
                                ForEach(viewModel.accounts, id: \.id) { account in
                                    AccountBalanceInputRow(
                                        accountName: account.name,
                                        text: bindingForClosing(accountId: account.id)
                                    )
                                    if account.id != viewModel.accounts.last?.id {
                                        Divider().opacity(0.5)
                                    }
                                }
                            }
                        }
                    } else if viewModel.errorMessage == nil {
                        ProgressView("Loading accounts...")
                            .padding()
                    }
                    
                    // MARK: - Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Daily Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(viewModel.isSaving || viewModel.accounts.isEmpty)
                }
            }
            .overlay {
                if viewModel.isSaving {
                    ZStack {
                        Color(.systemBackground).opacity(0.6).ignoresSafeArea()
                        ProgressView()
                            .padding(24)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(radius: 10)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
    
    // MARK: - Binding Helpers
    private func bindingForOpening(accountId: String) -> Binding<String> {
        Binding<String>(
            get: { viewModel.openingBalanceInputs[accountId] ?? "" },
            set: { viewModel.openingBalanceInputs[accountId] = $0 }
        )
    }
    
    private func bindingForClosing(accountId: String) -> Binding<String> {
        Binding<String>(
            get: { viewModel.closingBalanceInputs[accountId] ?? "" },
            set: { viewModel.closingBalanceInputs[accountId] = $0 }
        )
    }
}

// MARK: - UI Components

struct ModernFormCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            content
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
}

struct AccountBalanceInputRow: View {
    let accountName: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            // Contextual icon based on common account names
            Image(systemName: iconName(for: accountName))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text(accountName)
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            TextField("0.0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: 140)
        }
    }
    
    // Auto-selects a relevant SF Symbol based on the account name
    private func iconName(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("cash") { return "banknote" }
        if lowercased.contains("upi") || lowercased.contains("pay") { return "qrcode.viewfinder" }
        if lowercased.contains("card") { return "creditcard" }
        return "building.columns"
    }
}
