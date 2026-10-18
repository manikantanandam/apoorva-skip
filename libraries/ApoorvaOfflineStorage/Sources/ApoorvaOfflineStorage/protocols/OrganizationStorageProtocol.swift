//
//  File.swift
//  ApoorvaOfflineStorage
//
//  Created by Manikanta Nandam on 18/10/26.
//

import Foundation
import ApoorvaModels

public protocol OrganizationStorageProtocol: Sendable {
    func getOrganizations() throws -> [Organization]
    func getOrganization(orgId: String) throws -> Organization?
    func saveOrganization(organization: Organization) throws
    func updateOrganization(organization: Organization) throws
    func deleteOrganization(orgId: String) throws
    func markAsDeleted(orgId: String) throws
    func saveOrganizations(organizations: [Organization]) throws
}
