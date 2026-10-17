//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 17/10/26.
//

import Foundation
import ApoorvaModels
import ApoorvaRepository

public protocol DailyCashflowManagerProtocol: Sendable {
    func getDailySummary(for date: Date) async throws -> DailyCashflowSummary
}

public final class DailyCashflowManager: DailyCashflowManagerProtocol {
    
    let repository: CashflowTransactionRepositoryProtocol
    
    public init(repository: CashflowTransactionRepositoryProtocol) {
        self.repository = repository
    }
    
    public func getDailySummary(for date: Date) async throws -> DailyCashflowSummary {
        let allTransactions = try await repository.getCashflowTransactions()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) ?? date
        
        var openingCash: Double = 0
        var openingUpi: Double = 0
        var todayTransactions: [CashflowTransaction] = []
        
        for tx in allTransactions {
            guard !tx.isDeleted else { continue }
            
            if tx.timestamp < startOfDay {
                // Calculate historical opening balance up to the selected date
                let impact = (tx.transactionType == .credit) ? tx.amount : -tx.amount
                if tx.paymentMode == .cash {
                    openingCash += impact
                } else if tx.paymentMode == .upi {
                    openingUpi += impact
                }
            } else if tx.timestamp >= startOfDay && tx.timestamp <= endOfDay {
                // Collect today's transactions
                todayTransactions.append(tx)
            }
        }
        
        // Sort today's transactions chronologically
        todayTransactions.sort { $0.timestamp < $1.timestamp }
        
        // Calculate closing balance by applying today's transactions to the opening balance
        var closingCash = openingCash
        var closingUpi = openingUpi
        
        for tx in todayTransactions {
            let impact = (tx.transactionType == .credit) ? tx.amount : -tx.amount
            if tx.paymentMode == .cash {
                closingCash += impact
            } else if tx.paymentMode == .upi {
                closingUpi += impact
            }
        }
        
        return DailyCashflowSummary(
            date: startOfDay,
            openingCash: openingCash,
            openingUpi: openingUpi,
            closingCash: closingCash,
            closingUpi: closingUpi,
            transactions: todayTransactions
        )
    }
}
