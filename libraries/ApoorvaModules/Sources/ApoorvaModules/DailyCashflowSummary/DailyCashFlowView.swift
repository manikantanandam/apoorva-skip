//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation
import SwiftUI
import ApoorvaModels

public struct DailyCashFlowView: View {
    
    @Bindable var viewModel: DailyCashFlowViewModel
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    public init(viewModel: DailyCashFlowViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Date Navigator
            HStack {
                Button(action: { viewModel.prevDate() }) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding()
                }
                
                Spacer()
                
                DatePicker("Selected Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                
                Spacer()
                
                Button(action: { viewModel.nextDate() }) {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .padding()
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            
            // MARK: - Daily Content
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let summary = viewModel.summary {
                        
                        // Opening Balance Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Opening Balance")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                ModernDailyStatBox(title: "Cash", value: summary.openingCash.description, color: .primary)
                                ModernDailyStatBox(title: "UPI", value: summary.openingUpi.description, color: .primary)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 16)
                        
                        // Transactions Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Transactions")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            if summary.transactions.isEmpty {
                                Text("No transactions recorded on this date.")
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 32)
                            } else {
                                ForEach(summary.transactions) { item in
                                    // Reusing the modern card layout from CashflowListView
                                    DailyCashflowCardRowView(item: item)
                                }
                            }
                        }
                        
                        // Closing Balance Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Closing Balance")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            LazyVGrid(columns: columns, spacing: 12) {
                                ModernDailyStatBox(title: "Cash", value: summary.closingCash.description, color: summary.closingCash >= 0 ? .green : .red)
                                ModernDailyStatBox(title: "UPI", value: summary.closingUpi.description, color: summary.closingUpi >= 0 ? .green : .red)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 24)
                        
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 60)
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .task {
            await viewModel.fetchSummary()
        }
    }
}

// MARK: - Modern Subviews

struct ModernDailyStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

struct DailyCashflowCardRowView: View {
    let item: CashflowTransaction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.category.rawValue)
                        .font(.headline)
                    
                    if let subCategory = item.subCategory?.rawValue, !subCategory.isEmpty {
                        Text(subCategory)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(item.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Divider()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type & Mode")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(item.transactionType.rawValue.capitalized) • \(item.paymentMode.rawValue.capitalized)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Amount")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.amount.description)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(item.transactionType == .credit ? Color.green : (item.transactionType == .debit ? Color.red : Color.primary))
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }
}
