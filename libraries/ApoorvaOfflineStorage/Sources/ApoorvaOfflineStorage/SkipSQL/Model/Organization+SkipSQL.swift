//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 12/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

extension Organization: @retroactive SQLCodable {
    
    public static var table: SQLTable {
        SQLTable(
            name: "Organization",
            columns: [
                idCol,
                nameCol,
                statusCol,
                createdAtCol,
                minVersionCol,
                currentThemeCol,
                accentColorCol,
                accountsCol,
                updatedAtCol,
                isDeletedCol
            ]
        )
    }
    
    public init(row: SQLRow, context: SQLContext) throws {
        let orgId = try Self.idCol.textValueRequired(in: row)
        let name = try Self.nameCol.textValueRequired(in: row)
        let status = try Self.statusCol.textValueRequired(in: row)
        let createdAt = try Self.createdAtCol.realValueRequired(in: row)
        
        let minVersion = Self.minVersionCol.textValue(in: row)
        let currentTheme = Self.currentThemeCol.textValue(in: row)
        let accentColor = Self.accentColorCol.textValue(in: row)
        
        // Deserialize accounts from JSON text
        var accounts: [Account] = [] // Update type if it is an array of custom models
        if let accountsJSONStr = Self.accountsCol.textValue(in: row) {
           accounts = accountsJSONStr.decodeJSON(as: [Account].self) ?? []
        }
        
        let updatedAt = try Self.updatedAtCol.realValueRequired(in: row)
        let isDeleted = try Self.isDeletedCol.longValueRequired(in: row)
        
        self.init(id: orgId,
                  name: name,
                  status: status,
                  createdAt: createdAt.date,
                  minVersion: minVersion ?? "",
                  currentTheme: currentTheme ?? "",
                  accentColor: accentColor ?? "",
                  accounts: accounts,
                  updatedAt: updatedAt.date,
                  isDeleted: isDeleted.boolValue)
    }
    
    public func encode(row: inout SkipSQLCore.SQLRow) throws {
        row[Self.idCol] = SQLValue(self.id)
        row[Self.nameCol] = SQLValue(self.name)
        row[Self.statusCol] = SQLValue(self.status)
        row[Self.createdAtCol] = SQLValue(self.createdAt.timeIntervalSince1970)
        
        row[Self.minVersionCol] = SQLValue(self.minVersion)
        row[Self.currentThemeCol] = SQLValue(self.currentTheme)
        row[Self.accentColorCol] = SQLValue(self.accentColor)
        
        // Serialize accounts to JSON text
        if let accountsData = try? JSONEncoder().encode(self.accounts),
           let accountsString = String(data: accountsData, encoding: .utf8) {
            row[Self.accountsCol] = SQLValue(accountsString)
        } else {
            row[Self.accountsCol] = .null
        }
        
        row[Self.updatedAtCol] = SQLValue(self.updatedAt.timeIntervalSince1970)
        row[Self.isDeletedCol] = SQLValue(self.isDeleted.intValue)
    }
    
    public static let idCol = SQLColumn(name: "id", type: .text, primaryKey: true)
    public static let nameCol = SQLColumn(name: "name", type: .text)
    public static let statusCol = SQLColumn(name: "status", type: .text)
    public static let createdAtCol = SQLColumn(name: "createdAt", type: .real)
    public static let minVersionCol = SQLColumn(name: "minVersion", type: .text)
    public static let currentThemeCol = SQLColumn(name: "currentTheme", type: .text)
    public static let accentColorCol = SQLColumn(name: "accentColor", type: .text)
    public static let accountsCol = SQLColumn(name: "accounts", type: .text) // Serializes JSON arrays automatically
    public static let updatedAtCol = SQLColumn(name: "updatedAt", type: .real)
    public static let isDeletedCol = SQLColumn(name: "isDeleted", type: .long)
}
