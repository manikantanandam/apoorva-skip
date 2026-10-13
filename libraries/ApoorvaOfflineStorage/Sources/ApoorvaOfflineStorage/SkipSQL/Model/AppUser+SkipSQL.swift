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
//extension AppUser: @retroactive SQLCodable {
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
//    public static let emailCol = SQLColumn(
//        name: "email",
//        type: .text
//    )
//    
//    public static let roleCol = SQLColumn(
//        name: "role",
//        type: .text
//    )
//    
//    public static let statusCol = SQLColumn(
//        name: "status",
//        type: .text
//    )
//    
//    public static let assignedOrgsCol = SQLColumn(
//        name: "assignedOrgs",
//        type: .text
//    )
//    
//    public static let createdAtCol = SQLColumn(
//        name: "createdAt",
//        type: .datetime
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
