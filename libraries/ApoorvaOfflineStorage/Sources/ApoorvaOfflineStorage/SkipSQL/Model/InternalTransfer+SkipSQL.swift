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
//extension InternalTransfer: @retroactive SQLCodable {
//    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
//    public static let fromAccountIdCol = SQLColumn(name: "fromAccountId", type: .text)
//    public static let toAccountIdCol = SQLColumn(name: "toAccountId", type: .text)
//    public static let amountCol = SQLColumn(name: "amount", type: .real)
//    public static let transferTypeCol = SQLColumn(name: "transferType", type: .text)
//    public static let timestampCol = SQLColumn(name: "timestamp", type: .datetime)
//    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .datetime)
//    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .boolean)
//}
