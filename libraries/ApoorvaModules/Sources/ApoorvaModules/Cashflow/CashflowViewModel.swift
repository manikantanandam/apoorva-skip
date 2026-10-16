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


@MainActor
@Observable
public class CashflowTransactionListViewModel {
    
    var transactions: [CashflowTransaction] = []
    
    let repository: CashflowTransactionRepositoryProtocol
    
    var sortOption: CashflowTransactionSortOption = .newest {
        didSet {
            sortItems()
        }
    }
    
    
    public init(repository: CashflowTransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    func prepareDate() async {
        print("Preparing data for customer view")
        do {
            print("get transactions")
            self.transactions = try await repository.getCashflowTransactions().sorted()
            print("sync transactions")
            try await repository.sync(force: false)
            print("get transactions")
            self.transactions = try await repository.getCashflowTransactions().sorted()
            print("got transactions after sync \(self.transactions.count)")
            
        } catch {
            print("CashflowTransaction items failed \(error.localizedDescription)")
        }
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

