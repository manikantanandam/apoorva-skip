//
//  FirestoreCoding.swift
//  ApoorvaServices
//

#if os(Android)
import Foundation
import SkipFirebaseFirestore

// skip-firebase exposes `FirestoreDecoder` on Android; Apple's SDK nests it in `Firestore`.
// This keeps call sites on `Firestore.Encoder()`/`Firestore.Decoder()` for both platforms.
extension Firestore {
    typealias Encoder = AndroidFirestoreEncoder
    typealias Decoder = FirestoreDecoder
}

/// skip-firebase's `FirestoreEncoder.encode` hands the Swift value itself to Java, which fatal-errors with
/// "Unable to bridge Swift instance" for app models. This encodes through JSON into plain Swift values
/// (`Bool`, `Int`, `Double`, `String`, arrays, dictionaries) that bridge, with dates as `Timestamp`
/// like the Apple SDK's `Firestore.Encoder`.
struct AndroidFirestoreEncoder {
    func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.container(keyedBy: DateKey.self)
            try container.encode(date.timeIntervalSince1970, forKey: .date)
        }
        let json = try JSONDecoder().decode(JSONValue.self, from: encoder.encode(value))
        guard case .object(let object) = json else {
            throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "Firestore documents must encode to an object"))
        }
        return Self.firestoreObject(object)
    }

    /// Drops nulls (the synthesized `Encodable` already omits nil optionals) so only bridgeable values remain.
    private static func firestoreObject(_ object: [String: JSONValue]) -> [String: Any] {
        object.compactMapValues(firestoreValue)
    }

    private static func firestoreValue(_ json: JSONValue) -> Any? {
        switch json {
        case .bool(let bool): return bool
        case .int(let int): return int
        case .double(let double): return double
        case .string(let string): return string
        case .null: return nil
        case .array(let array): return array.compactMap(firestoreValue)
        case .object(let object):
            if object.count == 1, let seconds = object[DateKey.date.rawValue]?.seconds {
                return Timestamp(date: Date(timeIntervalSince1970: seconds))
            }
            return firestoreObject(object)
        }
    }

    private enum DateKey: String, CodingKey {
        case date = "__apoorvaFirestoreDate"
    }

    /// JSON decoded into native Swift values, without `JSONSerialization`'s `NSNumber`s.
    private enum JSONValue: Decodable {
        case bool(Bool), int(Int), double(Double), string(String), null
        case array([JSONValue]), object([String: JSONValue])

        init(from decoder: Swift.Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() { self = .null }
            else if let bool = try? container.decode(Bool.self) { self = .bool(bool) }
            else if let int = try? container.decode(Int.self) { self = .int(int) }
            else if let double = try? container.decode(Double.self) { self = .double(double) }
            else if let string = try? container.decode(String.self) { self = .string(string) }
            else if let array = try? container.decode([JSONValue].self) { self = .array(array) }
            else { self = .object(try container.decode([String: JSONValue].self)) }
        }

        var seconds: TimeInterval? {
            switch self {
            case .int(let int): return TimeInterval(int)
            case .double(let double): return double
            default: return nil
            }
        }
    }
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
