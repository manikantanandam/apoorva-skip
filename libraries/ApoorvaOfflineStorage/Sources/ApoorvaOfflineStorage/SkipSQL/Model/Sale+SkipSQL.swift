////
////  File.swift
////  ApoorvaOfflineStorage
////
////  Created by Manikanta Nandam on 12/10/26.
////
//
//import ApoorvaModels
//import SkipSQL
//
//extension Sale: @retroactive SQLCodable {
//    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
//    public static let staffIdCol = SQLColumn(name: "staffId", type: .text)
//    public static let customerPhoneCol = SQLColumn(name: "customerPhone", type: .text)
//    public static let customerNameCol = SQLColumn(name: "customerName", type: .text)
//    public static let itemsCol = SQLColumn(name: "items", type: .text) // Serializes JSON arrays automatically
//    public static let subtotalCol = SQLColumn(name: "subtotal", type: .real)
//    public static let overallDiscountPercentCol = SQLColumn(name: "overallDiscountPercent", type: .real)
//    public static let overallDiscountAmountCol = SQLColumn(name: "overallDiscountAmount", type: .real)
//    public static let roundOffCol = SQLColumn(name: "roundOff", type: .real)
//    public static let netPayableCol = SQLColumn(name: "netPayable", type: .real)
//    public static let paymentsCol = SQLColumn(name: "payments", type: .text) // Serializes JSON dictionaries automatically
//    public static let timestampCol = SQLColumn(name: "timestamp", type: .datetime)
//    public static let sourceCol = SQLColumn(name: "source", type: .text)
//    public static let statusCol = SQLColumn(name: "status", type: .text)
//    public static let whatsappStatusCol = SQLColumn(name: "whatsappStatus", type: .text)
//    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .datetime)
//    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .boolean)
//}
