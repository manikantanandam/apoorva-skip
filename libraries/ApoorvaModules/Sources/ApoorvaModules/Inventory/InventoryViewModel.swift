//
//  InventoryViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaRepository
import ApoorvaModels
import ApoorvaUtilities

public enum InventorySortOption: String, CaseIterable {
    case name = "Name"
    case stock = "Stock"
    case lastSoldDate = "Last Sold Date"
    case updatedAt = "Updated At"
}

@MainActor
@Observable
public class InventoryViewModel {
    
    var items: [InventoryItem] = []
    
    let repository: InventoryItemRepositoryProtocol
    
    var sortOption: InventorySortOption = .name {
        didSet {
            if sortOption == oldValue {
                sortType = sortType.togglevalue
            }
            
            sortItems(by: sortType)
        }
    }
    
    var sortType: SortType = .ascending
    
    
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
    
    func sortItems(by type: SortType) {
            switch sortOption {
            case .name:
                items.sortByName(type: sortType)
            case .stock:
                items.sortByStockLevel(type: sortType)
            case .lastSoldDate:
                items.sortByLastSoldDate(type: sortType)
            case .updatedAt:
                items.sortByUpdatedAt(type: sortType)
            }
        }
}
