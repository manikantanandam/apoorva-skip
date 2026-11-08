//
//  PlatformConfigService.swift
//  ApoorvaServices
//

import Foundation
import FirebaseFirestore
import ApoorvaModels

public protocol PlatformConfigServicing: Sendable {
    /// Live app-wide config; yields defaults when the doc doesn't exist.
    func listen() -> AsyncStream<PlatformConfig>
    func fetch() async throws -> PlatformConfig
    /// SuperAdmin only (enforced by rules once they exist).
    func save(_ config: PlatformConfig) throws
}

/// `platform/config`: app flags, sign-in methods, minimum app version, plan limits.
/// Kept in Firestore rather than Remote Config so the Apoorva console can edit it.
public final class PlatformConfigService: PlatformConfigServicing, @unchecked Sendable {
    public static let path = "platform/config"
    private let store: FirestoreStoring

    public init(store: FirestoreStoring = FirebaseFirestoreStore()) {
        self.store = store
    }

    public func listen() -> AsyncStream<PlatformConfig> {
        let documents = store.listen(path: Self.path)
        return AsyncStream { continuation in
            let task = Task {
                for await document in documents {
                    continuation.yield(Self.decode(document))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func fetch() async throws -> PlatformConfig {
        Self.decode(try await store.getDocument(path: Self.path))
    }

    public func save(_ config: PlatformConfig) throws {
        var stamped = config
        stamped.updatedAt = Date()
        try store.setData(try Firestore.Encoder().encode(stamped), path: Self.path, merge: true)
    }

    static func decode(_ document: StoreDocument?) -> PlatformConfig {
        guard let document else { return PlatformConfig() }
        return (try? Firestore.Decoder().decode(PlatformConfig.self, from: document.data)) ?? PlatformConfig()
    }
}
