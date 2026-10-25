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

public enum SaleDateFilterOption: String, CaseIterable {
    case today = "Today"
    case last7Days = "Last 7 Days"
    case thisMonth = "This Month"
    case last3Months = "Last 3 Months"
    case thisYear = "This Year"
    case all = "All"
    case custom = "Custom"
}


@MainActor
@Observable
public class SaleListViewModel {
    
    // Holds the currently filtered and sorted sales for the view
    var sales: [Sale] = []
    
    // Holds all fetched sales from the repository
    private var allSales: [Sale] = []
    
    // Stats for the current filtered view
    var totalSalesCount: Int = 0
    var totalSubtotal: Double = 0
    var totalDiscount: Double = 0
    var totalNetPayable: Double = 0
    
    let repository: SaleRepositoryProtocol
    
    var sortOption: SaleSortOption = .name {
        didSet {
            sortItems()
        }
    }
    
    var dateFilter: SaleDateFilterOption = .today {
        didSet {
            applyFilterAndSort()
        }
    }
    
    var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date() {
        didSet { if dateFilter == .custom { applyFilterAndSort() } }
    }
    
    var customEndDate: Date = Date() {
        didSet { if dateFilter == .custom { applyFilterAndSort() } }
    }
    
    
    public init(repository: SaleRepositoryProtocol) {
        self.repository = repository
    }
    
    func prepareDate() async {
        print("Preparing data for customer view")
        do {
            print("get sales")
            self.allSales = try await repository.getSales().sorted()
            print("sync sales")
            try await repository.sync(force: false)
            print("get sales")
            self.allSales = try await repository.getSales().sorted()
            print("got sales after sync \(self.sales.count)")
            applyFilterAndSort()
            
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
    
    private func applyFilterAndSort() {
        let calendar = Calendar.current
        let now = Date()
        
        let filteredSales = allSales.filter { sale in
            switch dateFilter {
            case .today:
                return calendar.isDateInToday(sale.timestamp)
                
            case .last7Days:
                guard let pastDate = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: now)) else { return true }
                return sale.timestamp >= pastDate
                
            case .thisMonth:
                return calendar.isDate(sale.timestamp, equalTo: now, toGranularity: .month)
                
            case .last3Months:
                guard let pastDate = calendar.date(byAdding: .month, value: -3, to: now) else { return true }
                return sale.timestamp >= pastDate
                
            case .thisYear:
                return calendar.isDate(sale.timestamp, equalTo: now, toGranularity: .year)
                
            case .all:
                return true
                
            case .custom:
                let startOfDay = calendar.startOfDay(for: customStartDate)
                // Ensure the end date covers the very end of the selected day
                let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEndDate) ?? customEndDate
                return sale.timestamp >= startOfDay && sale.timestamp <= endOfDay
            }
        }
        
        self.sales = filteredSales
        calculateStats()
        sortItems()
    }
    
    private func calculateStats() {
        totalSalesCount = sales.count
        
        var tempSubtotal: Double = 0
        var tempDiscount: Double = 0
        var tempNetPayable: Double = 0
        
        for sale in sales {
            tempSubtotal += sale.subtotal
            tempDiscount += sale.overallDiscountAmount
            tempNetPayable += sale.netPayable
        }
        
        totalSubtotal = tempSubtotal
        totalDiscount = tempDiscount
        totalNetPayable = tempNetPayable
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

