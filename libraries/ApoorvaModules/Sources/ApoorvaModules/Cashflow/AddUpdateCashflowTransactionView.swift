import SwiftUI
import ApoorvaModels
import UIKit

public struct AddUpdateCashflowTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: AddUpdateCashflowTransactionViewModel
    
    public init(viewModel: AddUpdateCashflowTransactionViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - Amount & Date Card
                    ModernFormCard(title: "Transaction Details") {
                        VStack(spacing: 16) {
                            // Amount Input
                            HStack {
                                Text("₹")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                TextField("0.00", text: $viewModel.amountText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    // Change color based on transaction type for visual feedback
                                    .foregroundColor(viewModel.transactionType == .credit ? .green : .red)
                            }
                            .padding(.bottom, 4)
                            
                            Divider().opacity(0.5)
                            
                            // Date Picker
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.blue)
                                }
                                
                                DatePicker("Date", selection: $viewModel.timestamp)
                                    .labelsHidden()
                                    .font(.body) // Prevents cascading large fonts
                                Spacer()
                            }
                        }
                    }
                    
                    // MARK: - Type & Mode Card
                    ModernFormCard(title: "Type & Mode") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Type")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Picker("Type", selection: $viewModel.transactionType) {
                                    Text("Credit (In)").tag(CashflowTransaction.TransactionType.credit)
                                    Text("Debit (Out)").tag(CashflowTransaction.TransactionType.debit)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 200)
                            }
                            
                            Divider().opacity(0.5)
                            
                            HStack {
                                Text("Mode")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Picker("Mode", selection: $viewModel.paymentMode) {
                                    Text("Cash").tag(CashflowTransaction.PaymentMode.cash)
                                    Text("UPI").tag(CashflowTransaction.PaymentMode.upi)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 200)
                            }
                        }
                    }
                    
                    // MARK: - Account Selection Card
                    ModernFormCard(title: "Accounts") {
                        VStack(spacing: 16) {
                            if viewModel.accounts.isEmpty {
                                ProgressView("Loading accounts...")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                HStack {
                                    Text("From Account")
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                    Picker("From Account", selection: $viewModel.fromAccountId) {
                                        Text("None").tag("")
                                        ForEach(viewModel.accounts, id: \.id) { account in
                                            Text(account.name).tag(account.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.secondary)
                                }
                                
                                Divider().opacity(0.5)
                                
                                HStack {
                                    Text("To Account")
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                    Picker("To Account", selection: $viewModel.toAccountId) {
                                        Text("None").tag("")
                                        ForEach(viewModel.accounts, id: \.id) { account in
                                            Text(account.name).tag(account.id)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.secondary)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Categorization Card
                    ModernFormCard(title: "Categorization") {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Category")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Picker("Category", selection: $viewModel.category) {
                                    ForEach(CashflowCategory.allCases, id: \.self) { cat in
                                        Text(cat.rawValue).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.secondary)
                            }
                            
                            Divider().opacity(0.5)
                            
                            HStack {
                                Text("Sub-Category")
                                    .font(.system(size: 16, weight: .medium))
                                Spacer()
                                Picker("Sub-Category", selection: $viewModel.subCategory) {
                                    ForEach(CashflowSubCategory.allCases, id: \.self) { sub in
                                        Text(sub.rawValue).tag(sub)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(.secondary)
                            }
                        }
                    }
                    
                    // MARK: - Details Card
                    ModernFormCard(title: "Additional Details") {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                TextField("Particulars (e.g. Paint supplies)", text: $viewModel.particulars)
                                    .font(.body)
                            }
                            
                            Divider().opacity(0.5)
                            
                            HStack {
                                Image(systemName: "person")
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                TextField("Person (Optional)", text: $viewModel.person)
                                    .font(.body)
                            }
                        }
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
            .navigationTitle(viewModel.isUpdating ? "Edit Transaction" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        // Explicitly restrict the size to block the HomeView font cascade
                        .font(.system(size: 17, weight: .regular))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let success = await viewModel.save()
                            if success { dismiss() }
                        }
                    }
                    // Explicitly restrict the size and keep it bold
                    .font(.system(size: 17, weight: .bold))
                    .disabled(viewModel.isSaving || viewModel.amountText.isEmpty)
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
        .task {
            await viewModel.fetchAccounts()
        }
    }
}
