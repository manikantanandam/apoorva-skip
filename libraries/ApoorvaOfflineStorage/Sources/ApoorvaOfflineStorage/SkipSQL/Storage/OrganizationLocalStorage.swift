//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

public final class OrganizationLocalStorage: OrganizationStorageProtocol {
    
    private let database: SkipSqlDatabase
    
    public init(database: SkipSqlDatabase) {
        self.database = database
    }
    
    public func getOrganizations() throws -> [Organization] {
        do {
            let allOrganizations: [Organization] = try database.context.fetchAll(Organization.self)
            return allOrganizations.sorted { $0.name < $1.name }
        } catch let error {
            if let error = error as? SQLError {
                print("SQL Error: \(error.localizedDescription)")
            }
            return []
        }
    }
    
    public func getOrganization(orgId: String) throws -> Organization? {
        return try database.context.fetch(Organization.self, primaryKeys: [.text(orgId)])
    }
    
    public func saveOrganization(organization: Organization) throws {
        try database.context.insert(organization)
    }
    
    public func updateOrganization(organization: Organization) throws {
        let query = """
        UPDATE \(Organization.table.name)
        SET name = ?, status = ?, createdAt = ?, minVersion = ?, currentTheme = ?, accentColor = ?, accounts = ?, updatedAt = ?, isDeleted = ?
        WHERE id = ?;
        """
        
        // Serialize accounts to JSON text
        let accountsValue: SQLValue
        if let accountsData = try? JSONEncoder().encode(organization.accounts),
           let accountsString = String(data: accountsData, encoding: .utf8) {
            accountsValue = .text(accountsString)
        } else {
            accountsValue = .null
        }

        try database.context.exec(sql: query, parameters: [
            .text(organization.name),
            .text(organization.status),
            .real(organization.createdAt.timeIntervalSince1970),
            .text(organization.minVersion),
            .text(organization.currentTheme),
            .text(organization.accentColor),
            accountsValue,
            .real(organization.updatedAt.timeIntervalSince1970),
            .long(organization.isDeleted.int64Value),
            .text(organization.id)
        ])
    }
    
    public func deleteOrganization(orgId: String) throws {
        let query = "DELETE FROM \(Organization.table.name) WHERE id = ?;"
        try database.context.exec(sql: query, parameters: [.text(orgId)])
    }
    
    public func markAsDeleted(orgId: String) throws {
        let query = "UPDATE \(Organization.table.name) SET isDeleted = 1, updatedAt = ? WHERE id = ?;"
        try database.context.exec(sql: query, parameters: [
            .real(Date().timeIntervalSince1970),
            .text(orgId)
        ])
    }
    
    public func saveOrganizations(organizations: [Organization]) throws {
        guard !organizations.isEmpty else { return }
        
        let query = """
        INSERT OR REPLACE INTO \(Organization.table.name) (
            id, name, status, createdAt, minVersion, currentTheme, accentColor, accounts, updatedAt, isDeleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        try database.context.exec(sql: "BEGIN TRANSACTION;")
        
        do {
            for org in organizations {
                let accountsValue: SQLValue
                if let accountsData = try? JSONEncoder().encode(org.accounts),
                   let accountsString = String(data: accountsData, encoding: .utf8) {
                    accountsValue = .text(accountsString)
                } else {
                    accountsValue = .null
                }
                
                try database.context.exec(sql: query, parameters: [
                    .text(org.id),
                    .text(org.name),
                    .text(org.status),
                    .real(org.createdAt.timeIntervalSince1970),
                    .text(org.minVersion),
                    .text(org.currentTheme),
                    .text(org.accentColor),
                    accountsValue,
                    .real(org.updatedAt.timeIntervalSince1970),
                    .long(org.isDeleted.int64Value)
                ])
            }
            try database.context.exec(sql: "COMMIT;")
        } catch {
            try? database.context.exec(sql: "ROLLBACK;")
            throw error
        }
    }
}
