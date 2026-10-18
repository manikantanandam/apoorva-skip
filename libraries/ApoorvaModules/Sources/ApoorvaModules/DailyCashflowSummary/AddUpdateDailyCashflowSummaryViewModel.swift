// AddUpdateDailyCashflowSummaryViewModel.swift
import Foundation
import SwiftUI
import ApoorvaModels
import ApoorvaRepository

@MainActor
@Observable
public class AddUpdateDailyCashflowSummaryViewModel {
    public var date: Date
    
    // Use dictionaries to hold the text input state for each account ID
    public var openingBalanceInputs: [String: String] = [:]
    public var closingBalanceInputs: [String: String] = [:]
    
    // We need the accounts to build the UI dynamically
    public var accounts: [Account] = []
    
    public var isSaving: Bool = false
    public var errorMessage: String?
    
    private let repository: DailyCashflowSummaryRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let organizationRepository: OrganizationRepositoryProtocol // Injected OrganizationRepository
    
    public init(repository: DailyCashflowSummaryRepositoryProtocol,
                userRepository: UserRepositoryProtocol,
                organizationRepository: OrganizationRepositoryProtocol,
                existingSummary: DailyCashflowSummary? = nil,
                date: Date = Date()) {
        
        self.repository = repository
        self.userRepository = userRepository
        self.organizationRepository = organizationRepository
        self.date = existingSummary?.date ?? date
        
        // Initializing with existing data is handled in fetchAccounts to ensure we have the accounts list first
        Task {
            await fetchAccounts(existingSummary: existingSummary)
        }
    }
    
    private func fetchAccounts(existingSummary: DailyCashflowSummary?) async {
        do {
            let user = try await userRepository.getCurrentUser()
            
            // Get the orgId from the user's selected snapshot
            guard let orgId = user.selectedOrganization?.orgId else {
                self.errorMessage = "No organization selected."
                return
            }
            
            // Fetch the full organization details from the repository
            print("getting organization details")
            guard let fullOrganization = try await organizationRepository.getOrganization(orgId: orgId) else {
                self.errorMessage = "Organization details not found."
                return
            }
            
            let orgAccounts = fullOrganization.accounts
            self.accounts = orgAccounts
            print("Accounts receive \(self.accounts)")
            // Initialize input dictionaries
            for account in orgAccounts {
                // Populate with existing data if available, otherwise ""
                if let summary = existingSummary {
                    let opBalance = summary.openingBalances.first(where: { $0.id == account.id })?.balance ?? 0.0
                    let clBalance = summary.closingBalances.first(where: { $0.id == account.id })?.balance ?? 0.0
                    
                    self.openingBalanceInputs[account.id] = String(opBalance)
                    self.closingBalanceInputs[account.id] = String(clBalance)
                } else {
                    self.openingBalanceInputs[account.id] = ""
                    self.closingBalanceInputs[account.id] = ""
                }
            }
        } catch {
            self.errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }
    }
    
    public func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        
        // Map the string inputs back to AccountBalance objects
        var finalOpeningBalances: [AccountBalance] = []
        var finalClosingBalances: [AccountBalance] = []
        
        for account in accounts {
            let opString = openingBalanceInputs[account.id] ?? "0"
            let clString = closingBalanceInputs[account.id] ?? "0"
            
            let opDouble = Double(opString) ?? 0.0
            let clDouble = Double(clString) ?? 0.0
            
            finalOpeningBalances.append(AccountBalance(id: account.id, balance: opDouble))
            finalClosingBalances.append(AccountBalance(id: account.id, balance: clDouble))
        }
        
        let summary = DailyCashflowSummary(
            date: date,
            openingBalances: finalOpeningBalances,
            closingBalances: finalClosingBalances,
            updatedAt: Date.now.timeIntervalSince1970
        )
        
        do {
            print("Saving summary \(summary)")
            try await repository.saveDailyCashflowSummary(summary: summary)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
