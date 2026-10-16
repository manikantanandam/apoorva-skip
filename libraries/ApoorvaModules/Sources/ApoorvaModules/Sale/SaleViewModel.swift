//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 15/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

public enum SaleSortOption: String, CaseIterable {
    case name = "Name"
    case phoneNumber = "Phone"
    case oldest = "Oldest"
    case newest = "Newest"
}


@MainActor
@Observable
public class SaleListViewModel {
    
    var sales: [Sale] = []
    
    let repository: SaleRepositoryProtocol
    
    var sortOption: SaleSortOption = .name {
        didSet {
            sortItems()
        }
    }
    
    
    public init(repository: SaleRepositoryProtocol) {
        self.repository = repository
    }
    
    func prepareDate() async {
        print("Preparing data for customer view")
        do {
            print("get sales")
            self.sales = try await repository.getSales().sorted()
            print("sync sales")
            try await repository.sync(force: false)
            print("get sales")
            self.sales = try await repository.getSales().sorted()
            print("got sales after sync \(self.sales.count)")
            
        } catch {
            print("Sale items failed \(error.localizedDescription)")
        }
    }
    
    func forceSync() async {
        do {
            try await repository.sync(force: true)
            print("get sales")
            self.sales = try await repository.getSales().sorted()
            
        } catch {
            print("Sale items failed \(error.localizedDescription)")
        }
    }
    
    func sortItems() {
            switch sortOption {
            case .name:
                sales.sort { $0.customerName > $1.customerName } // Uses the default Comparable conformance (<) from Sale
            case .phoneNumber:
                // Sorting descending by default to show highest stock first
                sales.sort { $0.customerPhone > $1.customerPhone }
            case .oldest:
                // Sorting descending to show most recently sold first. Nil dates go to the bottom.
                sales.sort { $0.timestamp < $1.timestamp }
            case .newest:
                sales.sort { $0.timestamp > $1.timestamp }
            }
        }
}

