// DailyCashFlowViewModel.swift
import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class DailyCashFlowViewModel {
    
    public var selectedDate: Date = Date() {
        didSet {
            Task { await fetchData() }
        }
    }
    
    public var summary: DailyCashflowSummary?
    public var transactions: [CashflowTransaction] = [] // Holds the daily transactions
    public var isLoading: Bool = false
    
    private let repository: DailyCashflowSummaryRepositoryProtocol
    private let cashflowRepository: CashflowTransactionRepositoryProtocol
    
    public init(repository: DailyCashflowSummaryRepositoryProtocol,
                cashflowRepository: CashflowTransactionRepositoryProtocol) {
        self.repository = repository
        self.cashflowRepository = cashflowRepository
    }
    
    // Renamed from fetchSummary to fetchData to reflect it grabs both
    public func fetchData() async {
        isLoading = true
        
        // 1. Fetch Summary
        do {
            self.summary = try await repository.getDailyCashflowSummary(id: selectedDate.toString(format: "dd-MM-yyyy"))
            try await repository.sync(force: true)
            self.summary = try await repository.getDailyCashflowSummary(id: selectedDate.toString(format: "dd-MM-yyyy"))
        } catch {
            print("Failed to fetch daily summary: \(error.localizedDescription)")
        }
        
        // 2. Fetch Transactions for Selected Date
        do {
            let allTransactions = try await cashflowRepository.getCashflowTransactions()
            
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: selectedDate)
            let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: selectedDate) ?? selectedDate
            
            self.transactions = allTransactions.filter { tx in
                !tx.isDeleted && tx.timestamp >= startOfDay && tx.timestamp <= endOfDay
            }.sorted(by: { $0.timestamp < $1.timestamp })
            
        } catch {
            print("Failed to fetch transactions: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    public func deleteTransaction(id: String) async {
        do {
            try await cashflowRepository.markAsDeleted(id: id)
            await fetchData() // Refresh the list after soft delete
        } catch {
            print("Failed to delete transaction: \(error.localizedDescription)")
        }
    }
    
    public func nextDate() {
        if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectedDate = next
        }
    }
    
    public func prevDate() {
        if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = prev
        }
    }
}
