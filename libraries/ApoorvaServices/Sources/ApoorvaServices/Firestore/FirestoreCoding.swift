//
//  FirestoreCoding.swift
//  ApoorvaServices
//

#if os(Android)
import Foundation
import SkipFirebaseFirestore

// skip-firebase exposes `FirestoreEncoder`/`FirestoreDecoder` on Android; Apple's SDK nests them in `Firestore`.
// This keeps call sites on `Firestore.Encoder()`/`Firestore.Decoder()` for both platforms.
extension Firestore {
    typealias Encoder = FirestoreEncoder
    typealias Decoder = FirestoreDecoder
}

extension FirestoreDecoder {
    /// Native Swift can't see skip-firebase's reified `decode`, so decode through JSON like the Apple SDK's
    /// `decode(_:from:)`. Timestamps and dates arrive as seconds since 1970.
    func decode<T: Decodable>(_ type: T.Type, from data: [String: Any]) throws -> T {
        let json = try JSONSerialization.data(withJSONObject: Self.jsonCompatible(data))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(type, from: json)
    }

    private static func jsonCompatible(_ value: Any) -> Any {
        switch value {
        case let timestamp as Timestamp: return timestamp.dateValue().timeIntervalSince1970
        case let date as Date: return date.timeIntervalSince1970
        case let dictionary as [String: Any]: return dictionary.mapValues { jsonCompatible($0) }
        case let array as [Any]: return array.map { jsonCompatible($0) }
        default: return value
        }
    }
}
#endif
