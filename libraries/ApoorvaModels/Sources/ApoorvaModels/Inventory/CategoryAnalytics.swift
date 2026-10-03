//
//  File.swift
//  ApoorvaModels
//
//  Created by Manikanta Nandam on 12/07/26.
//

import Foundation

struct CategoryAnalytics: Codable, Sendable {
    let categoryName: String
    let categoryId: String
    let totalQty: Int
    let totalRevenue: Double
}
