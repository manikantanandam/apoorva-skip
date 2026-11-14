import Foundation

/// Helper to ensure all Firestore write payloads include an `id` field matching the document ID.
public enum FirestorePayloadHelper {

    /// Adds or ensures the `id` field in a Firestore payload dictionary.
    /// - Parameters:
    ///   - payload: The document payload to modify (will be mutated)
    ///   - id: The document ID to set
    /// - Returns: The modified payload with `id` field set
    @discardableResult
    public static func ensureIdField(in payload: inout [String: Any], id: String) -> [String: Any] {
        payload["id"] = id
        return payload
    }

    /// Adds or ensures the `id` field in a Firestore payload dictionary (non-mutating).
    /// - Parameters:
    ///   - payload: The document payload
    ///   - id: The document ID to set
    /// - Returns: A new payload dictionary with `id` field set
    public static func payloadWithId(_ payload: [String: Any], id: String) -> [String: Any] {
        var result = payload
        result["id"] = id
        return result
    }
}
