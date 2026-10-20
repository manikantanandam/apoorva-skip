//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels

public protocol OrganizationStorageProtocol: Sendable {
    func getOrganizations() async throws -> [Organization]
    func getOrganization(orgId: String) async throws -> Organization?
    func saveOrganization(organization: Organization) async throws
    func updateOrganization(organization: Organization) async throws
    func deleteOrganization(orgId: String) async throws
    func markAsDeleted(orgId: String) async throws
    func saveOrganizations(organizations: [Organization]) async throws
}
