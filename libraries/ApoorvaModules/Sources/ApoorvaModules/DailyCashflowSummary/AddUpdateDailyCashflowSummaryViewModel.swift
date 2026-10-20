// AddUpdateDailyCashflowSummaryViewModel.swift
import Foundation
import SwiftUI
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class AddUpdateDailyCashflowSummaryViewModel {
    public var date: Date
    
    // Add didSet to automatically recalculate when the user types
    public var openingBalanceInputs: [String: String] = [:] {
        didSet {
            calculateClosingBalances()
        }
    }
    
    // Restored as a stored property
    public var closingBalanceInputs: [String: String] = [:]
    
    public var accounts: [Account] = []
    
    public var isSaving: Bool = false
    public var errorMessage: String?
    
    public var dayTransactions: [CashflowTransaction] = []
    
    private let repository: DailyCashflowSummaryRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let organizationRepository: OrganizationRepositoryProtocol
    private let cashflowRepository: CashflowTransactionRepositoryProtocol
    
    public init(repository: DailyCashflowSummaryRepositoryProtocol,
                userRepository: UserRepositoryProtocol,
                organizationRepository: OrganizationRepositoryProtocol,
                cashflowRepository: CashflowTransactionRepositoryProtocol,
                existingSummary: DailyCashflowSummary? = nil,
                date: Date = Date()) {
        
        self.repository = repository
        self.userRepository = userRepository
        self.organizationRepository = organizationRepository
        self.cashflowRepository = cashflowRepository
        self.date = existingSummary?.date ?? date
        
        Task {
            await fetchInitialData(existingSummary: existingSummary)
        }
    }
    
    func fetchInitialData(existingSummary: DailyCashflowSummary?) async {
        do {
            let user = try await userRepository.getCurrentUser()
            guard let orgId = user.selectedOrganization?.orgId else {
                self.errorMessage = "No organization selected."
                return
            }
            guard let fullOrganization = try await organizationRepository.getOrganization(orgId: orgId) else {
                self.errorMessage = "Organization details not found."
                return
            }
            
            print("FUll organization \(fullOrganization)")
            
            self.accounts = fullOrganization.accounts
            print("Self account \(self.accounts)")
            
            // 1. Fetch Today's Transactions
            let allTx = try await cashflowRepository.getCashflowTransactions()
                .filter { $0.category != .shopSetup }r
            let startOfDay = Calendar.current.startOfDay(for: self.date)
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self.date) ?? self.date
            self.dayTransactions = allTx.filter { !$0.isDeleted && $0.timestamp >= startOfDay && $0.timestamp <= endOfDay }
            
            // 2. Fetch Previous Summary
            var previousSummary: DailyCashflowSummary? = nil
            if existingSummary == nil {
                let allSummaries = try await repository.getDailyCashflowSummaries()
                previousSummary = allSummaries
                    .filter { $0.date < self.date }
                    .sorted { $0.date > $1.date }
                    .first
                
                print("[revious summary \(previousSummary)")
            }
            
            // 3. Pre-fill Opening Balances
            var initialOpening: [String: String] = [:]
            for account in self.accounts {
                print("Setting initial opening for \(account.id)")
                if let summary = existingSummary {
                    let opBalance = summary.openingBalances.first(where: { $0.id == account.id })?.balance ?? 0.0
                    initialOpening[account.id] = String(opBalance)
                } else if let prev = previousSummary {
                    let prevClose = prev.closingBalances.first(where: { $0.id == account.id })?.balance ?? 0.0
                    initialOpening[account.id] = String(prevClose)
                } else {
                    initialOpening[account.id] = ""
                }
            }
            
            // Assigning this will trigger the didSet and calculate the closing balances immediately
            self.openingBalanceInputs = initialOpening
            
        } catch {
            self.errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
    }
    
    // Centralized calculation method updates the stored property directly
    private func calculateClosingBalances() {
        print("calculating closing balance")
        for account in accounts {
            let opString = openingBalanceInputs[account.id] ?? "0"
            let opening = Double(opString) ?? 0.0
            
            var netChange = 0.0
            for tx in dayTransactions {
                if tx.fromAccountId == account.id { netChange -= tx.amount }
                if tx.toAccountId == account.id { netChange += tx.amount }
            }
            
            // Format to 2 decimal places and store it
            closingBalanceInputs[account.id] = String(format: "%.2f", opening + netChange)
        }
    }
    
    public func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        
        var finalOpeningBalances: [AccountBalance] = []
        var finalClosingBalances: [AccountBalance] = []
        
        for account in accounts {
            let opString = openingBalanceInputs[account.id] ?? "0"
            let clString = closingBalanceInputs[account.id] ?? "0"
            
            finalOpeningBalances.append(AccountBalance(id: account.id, balance: Double(opString) ?? 0.0))
            finalClosingBalances.append(AccountBalance(id: account.id, balance: Double(clString) ?? 0.0))
        }
        
        let summary = DailyCashflowSummary(
            date: date,
            openingBalances: finalOpeningBalances,
            closingBalances: finalClosingBalances,
            updatedAt: Date.now.timeIntervalSince1970
        )
        
        do {
            try await repository.saveDailyCashflowSummary(summary: summary)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
