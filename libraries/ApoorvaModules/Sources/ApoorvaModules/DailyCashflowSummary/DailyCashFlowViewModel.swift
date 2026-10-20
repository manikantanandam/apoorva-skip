// DailyCashFlowViewModel.swift
import Foundation
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class DailyCashFlowViewModel {
    
    public var selectedDate: Date
    
    public var currentSummary: DailyCashflowSummary?
    private var previousSummary: DailyCashflowSummary? = nil
    public var transactions: [CashflowTransaction] = []
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
        do {
            isLoading = true
            
            self.currentSummary = try await repository.getDailyCashflowSummary(id: selectedDate.toString(format: "dd-MM-yyyy"))
            print("Current summary in fetch data is \(self.currentSummary)")
            self.accounts = try await getAccounts()
            
            if currentSummary == nil {
                try await createNewDailyCashFlowSummary()
            }
            try await updateCashflowTransactions()
            isLoading = false
        } catch {
            print("Unable to fetch the daily cashflow summary \(error.localizedDescription)")
        }
    }
    
    public func deleteTransaction(id: String) async {
        do {
            try await cashflowRepository.markAsDeleted(id: id)
            try await fetchData()
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
    
    public func toggleLockStatus() async {
        guard let currentSummary else { return }
        isLoading = true
        let updatedSummary = currentSummary.copyWith(
            updatedAt: Date.now.timeIntervalSince1970,
            locked: !currentSummary.locked
        )
        
        do {
            try await repository.updateDailyCashflowSummary(summary: updatedSummary)
            try await fetchData()
        } catch {
            print("Failed to toggle lock status: \(error.localizedDescription)")
            isLoading = false
        }
    }
    
    func refreshData() async {
        do {
            try await repository.refresh(for: selectedDate.toString(format: "dd-MM-yyyy"))
            
        } catch {
            print("Force sync failed \(error.localizedDescription)")
        }
        
    }
    
    func fetchSummary() {
        
    }
    
    func getAccounts() async throws -> [Account] {
        
        guard let orgId = try await getOrganizationId() else {
            return []
        }
        
        guard
            let fullOrganization = try await organizationRepository.getOrganization(
                orgId: orgId
            )
        else { return [] }
        
        return fullOrganization.accounts
    }
    
    func getOrganizationId() async throws -> String? {
        let user = try await userRepository.getCurrentUser()
        guard let orgId = user.selectedOrganization?.orgId else {
            return nil
        }
        
        return orgId
    }
    
    
}


private extension DailyCashFlowViewModel {
    func createNewDailyCashFlowSummary() async throws {
        let allSummaries = try await repository.getDailyCashflowSummaries()
        self.previousSummary = allSummaries
            .filter { $0.date < self.selectedDate }
            .sorted { $0.date > $1.date }
            .first
        
        let openingBalances = accounts.map { account in
            guard
                let prev = previousSummary,
                let closingBalance = prev.closingBalances.first(where: { $0.id == account.id })
            else {
                return AccountBalance(id: account.id, name: account.name, balance: 0)
            }
            
            return AccountBalance(id: account.id,
                                  name: account.name,
                                  balance: closingBalance.balance)
        }
        
        self.currentSummary = DailyCashflowSummary(
            date: selectedDate,
            openingBalances: openingBalances,
            closingBalances: [],
            updatedAt: Date.now.timeIntervalSince1970,
            locked: false
        )
    }
    
    func updateCashflowTransactions() async throws {
        let allTransactions = try await cashflowRepository.getCashflowTransactions()
            .filter { $0.category != .shopSetup }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: selectedDate) ?? selectedDate
        
        self.transactions = allTransactions.filter { tx in
            !tx.isDeleted && tx.timestamp >= startOfDay && tx.timestamp <= endOfDay
        }.sorted(by: { $0.timestamp < $1.timestamp })
    }
}
