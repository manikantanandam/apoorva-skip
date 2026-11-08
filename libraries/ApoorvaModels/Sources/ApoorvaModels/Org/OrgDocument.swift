//
//  OrgDocument.swift
//  ApoorvaModels
//

import Foundation

/// A document stored under `organizations/{orgId}/{collection}/{id}` and cached locally.
/// Conformers must not use dictionaries keyed by enums (Firestore's encoder turns those
/// into arrays) — use `[String: X]` instead.
public protocol OrgDocument: Codable, Sendable, Identifiable, Hashable where ID == String {
    static var collection: String { get }
    var id: String { get }
    var updatedAt: Date? { get set }
    var isDeleted: Bool { get set }
}
