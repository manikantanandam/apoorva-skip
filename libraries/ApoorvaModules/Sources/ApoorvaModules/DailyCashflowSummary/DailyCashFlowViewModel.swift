//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

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
    
    let repository: DailyCashflowSummaryRepositoryProtocol
    
    public init(repository: DailyCashflowSummaryRepositoryProtocol) {
        self.repository = repository
    }
    
    public func fetchSummary() async {
        isLoading = true
        do {
            self.summary = try await repository.getDailyCashflowSummary(id: selectedDate.toString(format: "dd-MM-yyyy"))
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
