//
//  DailyCashflowListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 24/10/26.
//

import SwiftUI
import ApoorvaUtilities
import ApoorvaModels

public struct DailyCashflowListView: View {
    
    @Bindable var viewModel: DailyCashFlowListViewModel
    
    var makeDailyCashFlowView: (Date) -> DailyCashFlowView
    
    public init(viewModel: DailyCashFlowListViewModel,
                @ViewBuilder makeDailyCashFlowView: @escaping (Date) -> DailyCashFlowView) {
        self.viewModel = viewModel
        self.makeDailyCashFlowView = makeDailyCashFlowView
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Loop through the summaries provided by the view model[cite: 26, 27]
                ForEach(viewModel.summaries, id: \.id) { summary in
                    // 3. Wrap the card in a NavigationLink passing the summary's date
                    NavigationLink(destination: makeDailyCashFlowView(summary.date)) {
                        cashflowCard(for: summary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .task {
            await viewModel.fetchData() // Fetch data on load
        }
    }
    
    // Extracted into a separate view builder for cleaner code
    @ViewBuilder
    private func cashflowCard(for summary: DailyCashflowSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Header: Date and ID
            HStack {
                
                Spacer()
                
                Text("#\(summary.id.prefix(8))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(UIColor.tertiarySystemFill)) // Adapts better to dark mode
                    .clipShape(Capsule())
            }
            
            Divider()
            
            // Body: Opening and Closing Balances[cite: 27]
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opening")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(summary.totalOpening.string)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Closing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(summary.totalClosing.string)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green) // Highlights the final daily amount
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 0.5)
                )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}
