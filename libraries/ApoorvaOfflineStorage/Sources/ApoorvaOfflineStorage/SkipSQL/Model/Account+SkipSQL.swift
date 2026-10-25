////
////  File.swift
////  ApoorvaOfflineStorage
////
////  Created by Manikanta Nandam on 12/10/26.
////
//
//import Foundation
//
//// Account+SkipSQL.swift
//import ApoorvaModels
//import SkipSQL
//
//extension Account: @retroactive SQLCodable {
//    public static var table: SkipSQLCore.SQLTable {
//        SQLTable(
//            name: "DEMO_TABLE",
//            columns: [
//                idCol,
//                nameCol,
//                typeCol,
//                int,
//                dbl,
//                blb
//            ]
//        )
//    }
//    
//    public init(row: SkipSQLCore.SQLRow, context: SkipSQLCore.SQLContext) throws {
//        self.id = try Self.id.longValueRequired(in: row)
//
//    }
//    
//    public func encode(row: inout SkipSQLCore.SQLRow) throws {
//        row[Self.id] = SQLValue(self.id)
//                row[Self.txt] = SQLValue(self.txt)
//                row[Self.num] = SQLValue(self.num)
//                row[Self.int] = SQLValue(self.int)
//                row[Self.dbl] = SQLValue(self.dbl)
//                row[Self.blb] = SQLValue(self.blb)
//
//    }
//    
//    
//    public static let idCol = SQLColumn(
//        name: "id",
//        type: .text,
//        primaryKey: true
//    )
//    
//    public static let nameCol = SQLColumn(
//        name: "name",
//        type: .text
//    )
//    
//    public static let typeCol = SQLColumn(
//        name: "type",
//        type: .text
//    )
//    
//    public static let currentBalanceCol = SQLColumn(
//        name: "currentBalance",
//        type: .real
//    )
//    
//    public static let updatedAtCol = SQLColumn(
//        name: "updatedAt",
//        type: .datetime
//    )
//    
//    public static let isDeletedCol = SQLColumn(
//        name: "isDeleted",
//        type: .boolean
//    )
//}
