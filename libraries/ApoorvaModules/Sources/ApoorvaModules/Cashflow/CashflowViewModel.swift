//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 15/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

public enum CashflowTransactionSortOption: String, CaseIterable {
    case oldest = "Oldest"
    case newest = "Newest"
}

public enum CashflowDateFilterOption: String, CaseIterable {
    case today = "Today"
    case last7Days = "Last 7 Days"
    case thisMonth = "This Month"
    case last3Months = "Last 3 Months"
    case thisYear = "This Year"
    case all = "All"
    case custom = "Custom"
}

public enum CashflowTypeFilterOption: String, CaseIterable {
    case all = "All"
    case credit = "Credit"
    case debit = "Debit"
}

public enum CashflowPaymentModeFilterOption: String, CaseIterable {
    case all = "All"
    case cash = "Cash"
    case upi = "UPI"
}

@MainActor
@Observable
public class CashflowTransactionListViewModel {
    
    // Holds the currently filtered and sorted transactions for the view
    var transactions: [CashflowTransaction] = []
    
    // Holds all fetched transactions from the repository
    private var allTransactions: [CashflowTransaction] = []
    
    let repository: CashflowTransactionRepositoryProtocol
    
    var sortOption: CashflowTransactionSortOption = .newest {
        didSet {
            sortItems()
        }
    }
    
    var dateFilter: CashflowDateFilterOption = .today {
            didSet {
                applyFilterAndSort()
            }
        }
    
    var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() {
            didSet { if dateFilter == .custom { applyFilterAndSort() } }
        }
        
        var customEndDate: Date = Date() {
            didSet { if dateFilter == .custom { applyFilterAndSort() } }
        }
    
    var typeFilter: CashflowTypeFilterOption = .all {
            didSet { applyFilterAndSort() }
        }
        var paymentModeFilter: CashflowPaymentModeFilterOption = .all {
            didSet { applyFilterAndSort() }
        }
        var categoryFilter: String = "All" {
            didSet { applyFilterAndSort() }
        }
        var subCategoryFilter: String = "All" {
            didSet { applyFilterAndSort() }
        }
        
        // Dynamic Filter Data
        var availableCategories: [String] = ["All"]
        var availableSubCategories: [String] = ["All"]
    
    
    public init(repository: CashflowTransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    func prepareDate() async {
        print("Preparing data for customer view")
        do {
            print("get transactions")
            self.allTransactions = try await repository.getCashflowTransactions().sorted()
            print("sync transactions")
            try await repository.sync(force: false)
            print("get transactions")
            self.allTransactions = try await repository.getCashflowTransactions().sorted()
            print("got transactions after sync \(self.transactions.count)")
            extractDynamicFilters()
            applyFilterAndSort()
            
        } catch {
            print("CashflowTransaction items failed \(error.localizedDescription)")
        }
    }
    
    private func extractDynamicFilters() {
            // Extract unique categories
            let cats = Set(allTransactions.map { $0.category })
            availableCategories = ["All"] + cats.sorted()
            
            // Extract unique subcategories
            let subCats = Set(allTransactions.compactMap { $0.subCategory }.filter { !$0.isEmpty })
            availableSubCategories = ["All"] + subCats.sorted()
            
            // Reset selected filters if the old selection no longer exists in the newly fetched data
            if !availableCategories.contains(categoryFilter) { categoryFilter = "All" }
            if !availableSubCategories.contains(subCategoryFilter) { subCategoryFilter = "All" }
        }
    
    private func applyFilterAndSort() {
            let calendar = Calendar.current
            let now = Date()
            
            let filteredTransactions = allTransactions.filter { item in
                // 1. Date Filter
                var dateMatches = false
                switch dateFilter {
                case .today:
                    dateMatches = calendar.isDateInToday(item.timestamp)
                case .last7Days:
                    if let pastDate = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) {
                        dateMatches = item.timestamp >= pastDate
                    } else { dateMatches = true }
                case .thisMonth:
                    dateMatches = calendar.isDate(item.timestamp, equalTo: now, toGranularity: .month)
                case .last3Months:
                    if let pastDate = calendar.date(byAdding: .month, value: -3, to: now) {
                        dateMatches = item.timestamp >= pastDate
                    } else { dateMatches = true }
                case .thisYear:
                    dateMatches = calendar.isDate(item.timestamp, equalTo: now, toGranularity: .year)
                case .all:
                    dateMatches = true
                case .custom:
                    let startOfDay = calendar.startOfDay(for: customStartDate)
                    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
                    dateMatches = item.timestamp >= startOfDay && item.timestamp <= endOfDay
                }
                
                guard dateMatches else { return false }
                
                // 2. Type Filter
                if typeFilter == .credit && item.transactionType != .credit { return false }
                if typeFilter == .debit && item.transactionType != .debit { return false }
                
                // 3. Payment Mode Filter
                if paymentModeFilter == .cash && item.paymentMode != .cash { return false }
                if paymentModeFilter == .upi && item.paymentMode != .upi { return false }
                
                // 4. Category Filter
                if categoryFilter != "All" && item.category != categoryFilter { return false }
                
                // 5. SubCategory Filter
                if subCategoryFilter != "All" && (item.subCategory ?? "") != subCategoryFilter { return false }
                
                return true
            }
            
            self.transactions = filteredTransactions
            sortItems()
        }
    
    func forceSync() async {
        do {
            try await repository.sync(force: true)
            print("get transactions")
            self.transactions = try await repository.getCashflowTransactions().sorted()
            
        } catch {
            print("CashflowTransaction items failed \(error.localizedDescription)")
        }
    }
    
    func update() async {
        do {
            for transaction in transactions {
                try await repository.saveCashflowTransaction(transaction: transaction)
            }
        } catch {
            print("Cashflow Update failed")
        }
    }
    
    func sortItems() {
            switch sortOption {
            case .oldest:
                // Sorting descending to show most recently sold first. Nil dates go to the bottom.
                transactions.sort { $0.timestamp < $1.timestamp }
            case .newest:
                transactions.sort { $0.timestamp > $1.timestamp }
            }
        }
}

