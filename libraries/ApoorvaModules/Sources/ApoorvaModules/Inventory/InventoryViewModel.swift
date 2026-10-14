//
//  InventoryViewModel.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaRepository
import ApoorvaModels

@MainActor
@Observable
public class InventoryViewModel {
    
    var items: [InventoryItem] = []
    
    let repository: InventoryItemRepositoryProtocol
    
    
    public init(repository: InventoryItemRepositoryProtocol) {
        self.repository = repository
    }
    
    func prepareDate() async {
        print("Preparing data for inventory view")
        do {
            print("get inventory items")
            self.items = try await repository.getInventoryItems().sorted()
            print("sync inventory items")
            try await repository.sync(force: false)
            print("get inventory items")
            self.items = try await repository.getInventoryItems().sorted()
            
        } catch {
            print("Inventory items failed \(error.localizedDescription)")
        }
    }
    
    func forceSync() async {
        do {
            try await repository.sync(force: true)
            print("get inventory items")
            self.items = try await repository.getInventoryItems().sorted()
            
        } catch {
            print("Inventory items failed \(error.localizedDescription)")
        }
    }
}
