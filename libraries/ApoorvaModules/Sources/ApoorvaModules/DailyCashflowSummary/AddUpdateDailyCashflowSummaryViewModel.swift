// AddUpdateDailyCashflowSummaryViewModel.swift
import Foundation
import SwiftUI
import ApoorvaModels
import ApoorvaRepository

enum DailyCashFlowSummaryContext {
    case add
    case update(DailyCashflowSummary)
}

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
    
    private let context: DailyCashFlowSummaryContext
    
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
        if let existingSummary {
            self.context = .update(existingSummary)
        } else {
            self.context = .add
        }
    }
    
    func fetchInitialData() async {
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
            
            self.accounts = fullOrganization.accounts
            
            // 1. Fetch Today's Transactions
            let allTx = try await cashflowRepository.getCashflowTransactions()
                .filter { $0.category != .shopSetup }
            let startOfDay = Calendar.current.startOfDay(for: self.date)
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: self.date) ?? self.date
            self.dayTransactions = allTx.filter { !$0.isDeleted && $0.timestamp >= startOfDay && $0.timestamp <= endOfDay }
            var previousSummary: DailyCashflowSummary? = nil
            var initialOpening: [String: String] = [:]

            switch context {
            case .add:
                
                let allSummaries = try await repository.getDailyCashflowSummaries()
                previousSummary = allSummaries
                    .filter { $0.date < self.date }
                    .sorted { $0.date > $1.date }
                    .first
                
                // 3. Pre-fill Opening Balances
                for account in self.accounts {
                    let prevClose = previousSummary?.closingBalances.first(where: { $0.id == account.id })?.balance ?? 00
                    initialOpening[account.id] = String(prevClose)
                }

            case .update(let dailyCashflowSummary):
                // 3. Pre-fill Opening Balances
                for account in self.accounts {
                    let opBalance = dailyCashflowSummary.openingBalances.first(where: { $0.id == account.id })?.balance ?? 0.0
                    initialOpening[account.id] = String(opBalance)
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
        print("Calculating the closing balances")
        for account in accounts {
            print("Account: \(account.id) - \(account.name): \(account.currentBalance)")
            let opString = openingBalanceInputs[account.id] ?? "0"
            let opening = Double(opString) ?? 0.0
            var netChange = 0.0
            for tx in dayTransactions {
                print(" ")
                print("Transaction \(tx)")
                print(" ")
                if tx.fromAccountId == account.id { netChange -= tx.amount }
                if tx.toAccountId == account.id { netChange += tx.amount }
            }
            print("Opening \(opening) :Net change \(netChange)")

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
            
            finalOpeningBalances.append(AccountBalance(id: account.id, name: account.name, balance: Double(opString) ?? 0.0))
            finalClosingBalances.append(AccountBalance(id: account.id, name: account.name, balance: Double(clString) ?? 0.0))
        }
        

        
        do {
            switch context {
            case .add:
                let summary = DailyCashflowSummary(
                    date: date,
                    openingBalances: finalOpeningBalances,
                    closingBalances: finalClosingBalances,
                    updatedAt: Date.now.timeIntervalSince1970,
                    locked: false
                )
                print("Saving daily transaction summary")
                try await repository.saveDailyCashflowSummary(summary: summary)
            case .update(let existingSummary):
                
                let summary = existingSummary.copyWith(
                    openingBalances: finalOpeningBalances,
                    closingBalances: finalClosingBalances,
                    updatedAt: Date.now.timeIntervalSince1970
                )
                print("Update daily transaction summary")
                try await repository.updateDailyCashflowSummary(summary: summary)
            }
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
