//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation
import ApoorvaModels

@MainActor
@Observable
public class DailyCashFlowViewModel {
    
    public var selectedDate: Date = Date() {
        didSet {
            Task { await fetchSummary() }
        }
    }
    
    public var summary: DailyCashflowSummary?
    public var isLoading: Bool = false
    
    let manager: DailyCashflowManagerProtocol
    
    public init(manager: DailyCashflowManagerProtocol) {
        self.manager = manager
    }
    
    public func fetchSummary() async {
        isLoading = true
        do {
            self.summary = try await manager.getDailySummary(for: selectedDate)
        } catch {
            print("Failed to fetch daily summary: \(error.localizedDescription)")
        }
        isLoading = false
    }
    
    public func nextDate() {
        if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
            selectedDate = next
        }
    }
    
    public func prevDate() {
        if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = prev
        }
    }
}
