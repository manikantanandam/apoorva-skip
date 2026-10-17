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
    case itemsSold = "ItemsSold"
    case soldAmount = "Sold Amount"
}

struct InventoryItemRow: Identifiable {
    let item: InventoryItem
    var itemsSold: Int
    var soldValue: Double
    
    var id: String { item.id }
}

@MainActor
@Observable
public class InventoryViewModel {
    
    var items: [InventoryItem] = []
    var rows: [InventoryItemRow] = []
    var sales: [Sale] = []
    
    var itemsCount: Int = 0
    var hotItemsCount: Int = 0
    
    let inventoryRepository: InventoryItemRepositoryProtocol
    let saleRepository: SaleRepositoryProtocol
    
    var sortOption: InventorySortOption = .name {
        didSet {
            if sortOption == oldValue {
                sortType = sortType.togglevalue
            }
            
            sortItems(by: sortType)
        }
    }
    
    var sortType: SortType = .ascending
    
    
    public init(inventoryRepository: InventoryItemRepositoryProtocol,
                saleRepository: SaleRepositoryProtocol) {
        self.inventoryRepository = inventoryRepository
        self.saleRepository = saleRepository
    }
    
    func prepareDate() async {
        print("Preparing data for inventory view")
        do {
            try await prepareReport()
            try await inventoryRepository.sync(force: false)
            try await saleRepository.sync(force: false)
            try await prepareReport()
        } catch {
            print("Inventory items failed \(error.localizedDescription)")
        }
    }
    
    func prepareReport() async throws {
        self.items = try await inventoryRepository.getInventoryItems().sorted()
        self.sales = try await saleRepository.getSales()
        itemsCount = items.count
        hotItemsCount = items.hotItems.count
        
        let saleItems = sales.flatMap { $0.items }
        var itemsDict: [String: InventoryItemRow] = [:]
        for saleItem in saleItems {
            
            
            let row = itemsDict[saleItem.categoryId]
            var finalRow: InventoryItemRow?
            
            if var row = row {
                row.itemsSold += saleItem.qty
                row.soldValue += saleItem.finalPrice
                finalRow = row
            } else {
                let item = items.first(where: { $0.id == saleItem.categoryId })
                if let item {
                    finalRow = InventoryItemRow(
                        item: item,
                        itemsSold: 0,
                        soldValue: 0
                    )
                }
            }
            
            
            itemsDict[saleItem.categoryId] = finalRow
        }
        self.rows = itemsDict.values.map { $0 }
    }
    
    func forceSync() async {
        do {
            try await inventoryRepository.sync(force: true)
            print("get inventory items in force sync")
            self.items = try await inventoryRepository.getInventoryItems().sorted()
            
        } catch {
            print("Inventory items failed force sync \(error.localizedDescription)")
        }
    }
    
    func sortItems(by type: SortType) {
            switch sortOption {
            case .name:
                rows.sortByName(type: sortType)
            case .stock:
                rows.sortByStockLevel(type: sortType)
            case .lastSoldDate:
                rows.sortByLastSoldDate(type: sortType)
            case .updatedAt:
                rows.sortByUpdatedAt(type: sortType)
            case .itemsSold:
                rows.sortByItemsSold(type: sortType)
            case .soldAmount:
                rows.sortBySoldAmount(type: sortType)
            }
        }
}



extension Array where Element == InventoryItemRow {
    mutating func sortByName(type: SortType) {
        switch type {
        case .ascending:
            sort(by: { $0.item.name.lowercased() > $1.item.name.lowercased() })
        case .descending:
            sort(by: { $0.item.name.lowercased() < $1.item.name.lowercased() })
        }
    }
    
    mutating func sortByStockLevel(type: SortType) {
        switch type {
        case .ascending:
            sort(by: { $0.item.currentStock > $1.item.currentStock })
        case .descending:
            sort(by: { $0.item.currentStock < $1.item.currentStock })
        }
    }
    
    mutating func sortByLastSoldDate(type: SortType) {
        switch type {
        case .ascending:
            sort {
                let date1 = $0.item.lastSoldDate ?? Date.distantPast
                let date2 = $1.item.lastSoldDate ?? Date.distantPast
                return date1 > date2
            }
        case .descending:
            sort {
                let date1 = $0.item.lastSoldDate ?? Date.distantPast
                let date2 = $1.item.lastSoldDate ?? Date.distantPast
                return date1 < date2
            }
        }
    }
    
    mutating func sortByUpdatedAt(type: SortType) {
        switch type {
        case .ascending:
            sort {
                let date1 = $0.item.updatedAt ?? Date.distantPast
                let date2 = $1.item.updatedAt ?? Date.distantPast
                return date1 > date2
            }
        case .descending:
            sort {
                let date1 = $0.item.updatedAt ?? Date.distantPast
                let date2 = $1.item.updatedAt ?? Date.distantPast
                return date1 < date2
            }
        }
    }
    
    mutating func sortByItemsSold(type: SortType) {
        switch type {
        case .ascending:
            sort(by: { $0.itemsSold > $1.itemsSold })
        case .descending:
            sort(by: { $0.itemsSold < $1.itemsSold })
        }
    }
    
    mutating func sortBySoldAmount(type: SortType) {
        switch type {
        case .ascending:
            sort(by: { $0.soldValue > $1.soldValue })
        case .descending:
            sort(by: { $0.soldValue < $1.soldValue })
        }
    }
    
    var hotItems: [InventoryItemRow] {
        filter { $0.item.isHotkey }
    }
}
