//
//  AuditLogger.swift
//  ApoorvaRepository
//

import Foundation
import ApoorvaModels
import ApoorvaLogging

private let logger = AppLogger(category: .sync)

public protocol AuditLogging: Sendable {
    func log(_ category: AuditCategory, action: String, summary: String, targetId: String?) async
}

/// Records sensitive actions. Logging never throws to the caller — a failed audit write must
/// not undo the action the user just took.
public struct AuditLogger: AuditLogging {
    private let repository: any OrgCollectionRepositoryProtocol<AuditEvent>
    private let context: OrgContextProviding

    public init(repository: any OrgCollectionRepositoryProtocol<AuditEvent>, context: OrgContextProviding) {
        self.repository = repository
        self.context = context
    }

    public func log(_ category: AuditCategory, action: String, summary: String, targetId: String? = nil) async {
        do {
            let actor = try await context.currentActor()
            try await repository.save(AuditEvent(
                category: category,
                action: action,
                summary: summary,
                actorId: actor.id,
                actorName: actor.name,
                targetId: targetId
            ))
        } catch {
            logger.error("Audit log failed for\(action): \(error)")
        }
    }
}
