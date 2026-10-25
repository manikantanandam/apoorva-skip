//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation

public struct Sale: Codable, Sendable, Identifiable {
    public let id: String
    public let staffId: String
    public let customerPhone: String
    public let customerName: String
    public let items: [SaleItem]
    
    public let subtotal: Double
    public let overallDiscountPercent: Double
    public let overallDiscountAmount: Double
    public let roundOff: Double
    public let netPayable: Double
    
    public let payments: [PaymentMode: Double]
    public let timestamp: Date // Assuming your custom Dart TimestampConverter outputs a standard Date format
    public let source: String
    public let status: String
    public let whatsappStatus: String
    
    // Add these to Sale.swift in ApoorvaModels
    public var updatedAt: Date?
    public var isDeleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, staffId, customerPhone, customerName, items, subtotal
        case overallDiscountPercent, overallDiscountAmount, roundOff
        case netPayable, payments, timestamp, source, status, whatsappStatus
        case updatedAt, isDeleted
    }
    
    public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // ID is missing in Firestore JSON, so default to empty string safely
            self.id = (try? container.decodeIfPresent(String.self, forKey: .id)) ?? ""
            
            // Safe Strings
            self.staffId = (try? container.decodeIfPresent(String.self, forKey: .staffId)) ?? "Unknown"
            self.customerPhone = (try? container.decodeIfPresent(String.self, forKey: .customerPhone)) ?? ""
            self.customerName = (try? container.decodeIfPresent(String.self, forKey: .customerName)) ?? "Walk-in"
            
            // Safe Arrays & Dicts
            self.items = (try? container.decodeIfPresent([SaleItem].self, forKey: .items)) ?? []
            self.payments = (try? container.decodeIfPresent([PaymentMode: Double].self, forKey: .payments)) ?? [:]
            
            // Safe Numbers (Dart 'num' to Swift 'Double' crashes often without this)
            self.subtotal = (try? container.decodeIfPresent(Double.self, forKey: .subtotal)) ?? 0.0
            self.overallDiscountPercent = (try? container.decodeIfPresent(Double.self, forKey: .overallDiscountPercent)) ?? 0.0
            self.overallDiscountAmount = (try? container.decodeIfPresent(Double.self, forKey: .overallDiscountAmount)) ?? 0.0
            self.roundOff = (try? container.decodeIfPresent(Double.self, forKey: .roundOff)) ?? 0.0
            self.netPayable = (try? container.decodeIfPresent(Double.self, forKey: .netPayable)) ?? 0.0
            
            // Safe Dates & Enums
            self.timestamp = (try? container.decodeIfPresent(Date.self, forKey: .timestamp)) ?? Date()
            self.source = (try? container.decodeIfPresent(String.self, forKey: .source)) ?? "Unknown"
            self.status = (try? container.decodeIfPresent(String.self, forKey: .status)) ?? "Completed"
            self.whatsappStatus = (try? container.decodeIfPresent(String.self, forKey: .whatsappStatus)) ?? "unsent"
            self.updatedAt = (try? container.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? Date()
            self.isDeleted = (try? container.decodeIfPresent(Bool.self, forKey: .isDeleted)) ?? false
        }
    
    public init(id: String,
                staffId: String,
                customerPhone: String,
                customerName: String,
                items: [SaleItem],
                subtotal: Double,
                overallDiscountPercent: Double,
                overallDiscountAmount: Double,
                roundOff: Double,
                netPayable: Double,
                payments: [PaymentMode: Double],
                timestamp: Date,
                source: String,
                status: String,
                whatsappStatus: String,
                updatedAt: Date? = nil,
                isDeleted: Bool = false) {
            self.id = id
            self.staffId = staffId
            self.customerPhone = customerPhone
            self.customerName = customerName
            self.items = items
            self.subtotal = subtotal
            self.overallDiscountPercent = overallDiscountPercent
            self.overallDiscountAmount = overallDiscountAmount
            self.roundOff = roundOff
            self.netPayable = netPayable
            self.payments = payments
            self.timestamp = timestamp
            self.source = source
            self.status = status
            self.whatsappStatus = whatsappStatus
            self.updatedAt = updatedAt
            self.isDeleted = isDeleted
        }
    
    // MARK: - Computed Properties
    var totalMRP: Double {
        return items.reduce(0.0) { $0 + ($1.stickerPrice * Double($1.qty)) }
    }
    
    var totalItemsDiscount: Double {
        return items.reduce(0.0) { $0 + ($1.unitDiscountAmount * Double($1.qty)) }
    }
    
    // Kept as subTotal (capital T) to mirror your Dart getter and avoid conflict with the stored subtotal
    var subTotal: Double {
        return totalMRP - totalItemsDiscount
    }
    
    var billAmount: Double {
        return subTotal - overallDiscountAmount
    }
    
    var totalSavings: Double {
        return totalItemsDiscount + overallDiscountAmount + roundOff
    }
}


extension Sale: Comparable {
    public static func == (lhs: borrowing Sale, rhs: borrowing Sale) -> Bool {
        return lhs.id == rhs.id
    }
    
    public static func < (lhs: Sale, rhs: Sale) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
    
    public static func > (lhs: Sale, rhs: Sale) -> Bool {
        return lhs.timestamp > rhs.timestamp
    }
}
