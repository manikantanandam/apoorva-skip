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
            applyFilterAndSort()
            
        } catch {
            print("CashflowTransaction items failed \(error.localizedDescription)")
        }
    }
    
    private func applyFilterAndSort() {
            let calendar = Calendar.current
            let now = Date()
            
            let filteredTransactions = allTransactions.filter { item in
                switch dateFilter {
                case .today:
                    return calendar.isDateInToday(item.timestamp)
                    
                case .last7Days:
                    guard let pastDate = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return true }
                    return item.timestamp >= pastDate
                    
                case .thisMonth:
                    return calendar.isDate(item.timestamp, equalTo: now, toGranularity: .month)
                    
                case .last3Months:
                    guard let pastDate = calendar.date(byAdding: .month, value: -3, to: now) else { return true }
                    return item.timestamp >= pastDate
                    
                case .thisYear:
                    return calendar.isDate(item.timestamp, equalTo: now, toGranularity: .year)
                    
                case .all:
                    return true
                    
                case .custom:
                    let startOfDay = calendar.startOfDay(for: customStartDate)
                    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
                    return item.timestamp >= startOfDay && item.timestamp <= endOfDay
                }
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

