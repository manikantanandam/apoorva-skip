//
//  InventoryViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaRepository
import ApoorvaModels

public enum InventorySortOption: String, CaseIterable {
    case name = "Name"
    case stock = "Stock"
    case lastSoldDate = "Last Sold Date"
}

@MainActor
@Observable
public class InventoryViewModel {
    
    var items: [InventoryItem] = []
    
    let repository: InventoryItemRepositoryProtocol
    
    var sortOption: InventorySortOption = .name {
        didSet {
            sortItems()
        }
    }
    
    
    public init(repository: InventoryItemRepositoryProtocol) {
        self.repository = repository
    }
    
    func prepareDate() async {
        print("Preparing data for inventory view")
        do {
            print("get inventory items")
            self.items = try await repository.getInventoryItems().sorted()
            print("Received items \(self.items.count)")
            print("sync inventory items")
            try await repository.sync(force: false)
            print("sync completed for inventory data")
            self.items = try await repository.getInventoryItems().sorted()
            
        } catch {
            print("Inventory items failed \(error.localizedDescription)")
        }
    }
    
    func forceSync() async {
        do {
            try await repository.sync(force: true)
            print("get inventory items in force sync")
            self.items = try await repository.getInventoryItems().sorted()
            
        } catch {
            print("Inventory items failed force sync \(error.localizedDescription)")
        }
    }
    
    func sortItems() {
            switch sortOption {
            case .name:
                items.sort() // Uses the default Comparable conformance (<) from InventoryItem
            case .stock:
                // Sorting descending by default to show highest stock first
                items.sort { $0.currentStock > $1.currentStock }
            case .lastSoldDate:
                // Sorting descending to show most recently sold first. Nil dates go to the bottom.
                items.sort {
                    let date1 = $0.lastSoldDate ?? Date.distantPast
                    let date2 = $1.lastSoldDate ?? Date.distantPast
                    return date1 > date2
                }
            }
        }
}
