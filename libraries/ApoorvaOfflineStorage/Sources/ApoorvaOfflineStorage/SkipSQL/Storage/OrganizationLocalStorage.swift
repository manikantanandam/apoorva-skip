//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels
import SkipSQL

public final actor OrganizationLocalStorage: OrganizationStorageProtocol {

    private let database: SkipSqlDatabase

    public init(database: SkipSqlDatabase) {
        self.database = database
    }

    public func getOrganizations() async throws -> [Organization] {
        do {
            let allOrganizations: [Organization] = try await database.withContext { context in
                try context.fetchAll(Organization.self)
            }
            return allOrganizations.sorted { $0.name < $1.name }
        } catch let error {
            if let error = error as? SQLError {
                print("SQL Error: \(error.localizedDescription)")
            }
            return []
        }
    }

    public func getOrganization(orgId: String) async throws -> Organization? {
        do {
            return try await database.withContext { context in
                try context.fetch(Organization.self, primaryKeys: [.text(orgId)])
            }
        } catch {
            if let error = error as? SQLError {
                print(error.msg)
            }
            throw error
        }

    }

    public func saveOrganization(organization: Organization) async throws {
        try await database.withContext { context in
            try context.insert(organization)
        }
    }

    public func updateOrganization(organization: Organization) async throws {
        let query = """
        UPDATE \(Organization.table.name)
        SET name = ?, status = ?, createdAt = ?, minVersion = ?, currentTheme = ?, accentColor = ?, accounts = ?, updatedAt = ?, isDeleted = ?, establishedAtInMs = ?
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

        try await database.withContext { context in
            try context.exec(sql: query, parameters: [
                .text(organization.name),
                .text(organization.status),
                .real(organization.createdAt.timeIntervalSince1970),
                .text(organization.minVersion),
                .text(organization.currentTheme),
                .text(organization.accentColor),
                accountsValue,
                .real(organization.updatedAt.timeIntervalSince1970),
                .long(organization.isDeleted.int64Value),
                .text(organization.id),
                .real(organization.establishedAtInMs)
            ])
        }
    }

    public func deleteOrganization(orgId: String) async throws {
        let query = "DELETE FROM \(Organization.table.name) WHERE id = ?;"
        try await database.withContext { context in
            try context.exec(sql: query, parameters: [.text(orgId)])
        }
    }

    public func markAsDeleted(orgId: String) async throws {
        let query = "UPDATE \(Organization.table.name) SET isDeleted = 1, updatedAt = ? WHERE id = ?;"
        try await database.withContext { context in
            try context.exec(sql: query, parameters: [
                .real(Date().timeIntervalSince1970),
                .text(orgId)
            ])
        }
    }

    public func saveOrganizations(organizations: [Organization]) async throws {
        guard !organizations.isEmpty else { return }

        let query = """
        INSERT OR REPLACE INTO \(Organization.table.name) (
            id, name, status, createdAt, minVersion, currentTheme, accentColor, accounts, updatedAt, isDeleted, establishedAtInMs
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        try await database.withContext { context in
            try context.transaction {
                for org in organizations {
                    let accountsValue: SQLValue
                    if let accountsData = try? JSONEncoder().encode(org.accounts),
                       let accountsString = String(data: accountsData, encoding: .utf8) {
                        accountsValue = .text(accountsString)
                    } else {
                        accountsValue = .null
                    }

                    try context.exec(sql: query, parameters: [
                        .text(org.id),
                        .text(org.name),
                        .text(org.status),
                        .real(org.createdAt.timeIntervalSince1970),
                        .text(org.minVersion),
                        .text(org.currentTheme),
                        .text(org.accentColor),
                        accountsValue,
                        .real(org.updatedAt.timeIntervalSince1970),
                        .long(org.isDeleted.int64Value),
                        .real(org.establishedAtInMs)
                    ])
                }
            }
        }
    }
}
