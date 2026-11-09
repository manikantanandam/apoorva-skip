//
//  AuditEvent.swift
//  ApoorvaModels
//

import Foundation

public enum AuditCategory: String, Codable, Sendable, CaseIterable {
    case bills, stock, money, staff, settings, security, platform
}

/// Append-only record of a sensitive action. Not tamper-proof until Firestore rules or
/// Cloud Functions enforce append-only writes.
public struct AuditEvent: OrgDocument {
    public static let collection = "auditEvents"

    public let id: String
    public let category: AuditCategory
    public let action: String
    public let summary: String
    public let actorId: String
    public let actorName: String
    public let targetId: String?
    public let createdAt: Date
    public var updatedAt: Date?
    public var isDeleted: Bool

    public init(id: String = UUID().uuidString,
                category: AuditCategory,
                action: String,
                summary: String,
                actorId: String,
                actorName: String,
                targetId: String? = nil,
                createdAt: Date = Date(),
                updatedAt: Date? = nil,
                isDeleted: Bool = false) {
        self.id = id
        self.category = category
        self.action = action
        self.summary = summary
        self.actorId = actorId
        self.actorName = actorName
        self.targetId = targetId
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.isDeleted = isDeleted
    }
}
