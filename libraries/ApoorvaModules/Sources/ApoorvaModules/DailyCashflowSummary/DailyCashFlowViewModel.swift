// DailyCashFlowViewModel.swift
import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class DailyCashFlowViewModel {
    
    public var selectedDate: Date
    
    public var summary: DailyCashflowSummary?
    public var transactions: [CashflowTransaction] = [] // Holds the daily transactions
    public var isLoading: Bool = false
    public var accounts: [Account] = []
    
    private let repository: DailyCashflowSummaryRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let organizationRepository: OrganizationRepositoryProtocol
    private let cashflowRepository: CashflowTransactionRepositoryProtocol
    
    public init(repository: DailyCashflowSummaryRepositoryProtocol,
                userRepository: UserRepositoryProtocol,
                organizationRepository: OrganizationRepositoryProtocol,
                cashflowRepository: CashflowTransactionRepositoryProtocol) {
        self.repository = repository
        self.cashflowRepository = cashflowRepository
        self.userRepository = userRepository
        self.organizationRepository = organizationRepository
        self.selectedDate = Date.from(day: 17, month: 10, year: 2025) ?? Date()
    }
    
    // Renamed from fetchSummary to fetchData to reflect it grabs both
    public func fetchData() async {
        print("fetch data is called")
        isLoading = true
        
        // 1. Fetch Summary
        do {
            
            
            self.summary = try await repository.getDailyCashflowSummary(id: selectedDate.toString(format: "dd-MM-yyyy"))
            try await repository.sync(force: false)
            self.summary = try await repository.getDailyCashflowSummary(id: selectedDate.toString(format: "dd-MM-yyyy"))
            let user = try await userRepository.getCurrentUser()
            guard let orgId = user.selectedOrganization?.orgId else {
                return
            }
            guard let fullOrganization = try await organizationRepository.getOrganization(orgId: orgId) else {
                return
            }
            self.accounts = fullOrganization.accounts
            
            var previousSummary: DailyCashflowSummary? = nil
            if summary == nil {
                let allSummaries = try await repository.getDailyCashflowSummaries()
                previousSummary = allSummaries
                    .filter { $0.date < self.selectedDate }
                    .sorted { $0.date > $1.date }
                    .first
                
                
                let openingBalances = accounts.map { account in
                    
                    guard
                        let prev = previousSummary,
                        let closingBalance = prev.closingBalances.first(where: { $0.id == account.id })
                    else  {
                        return AccountBalance(id: account.id, balance: 0)
                    }
                    
                    return AccountBalance(id: account.id, balance: closingBalance.balance)
                }
                
                self.summary = DailyCashflowSummary(
                    date: selectedDate,
                    openingBalances: openingBalances,
                    closingBalances: [],
                    updatedAt: Date.now.timeIntervalSince1970
                )
            }
            

            
            
        } catch {
            print("Failed to fetch daily summary: \(error.localizedDescription)")
        }
        
        // 2. Fetch Transactions for Selected Date
        do {
            let allTransactions = try await cashflowRepository.getCashflowTransactions()
                .filter { $0.category != .shopSetup }
            
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
