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
//extension Organization: @retroactive SQLCodable {
//    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
//    public static let nameCol = SQLColumn(name: "name", type: .text)
//    public static let statusCol = SQLColumn(name: "status", type: .text)
//    public static let createdAtCol = SQLColumn(name: "createdAt", type: .datetime)
//    public static let minVersionCol = SQLColumn(name: "minVersion", type: .text)
//    public static let currentThemeCol = SQLColumn(name: "currentTheme", type: .text)
//    public static let accentColorCol = SQLColumn(name: "accentColor", type: .text)
//    public static let accountsCol = SQLColumn(name: "accounts", type: .text) // Serializes JSON arrays automatically
//    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .datetime)
//    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .boolean)
//}
