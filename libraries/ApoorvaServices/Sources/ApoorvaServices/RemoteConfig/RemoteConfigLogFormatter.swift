//
//  RemoteConfigLogFormatter.swift
//  ApoorvaServices
//

import Foundation

/// Where a Remote Config value came from after a fetch.
enum RemoteConfigValueSource: String, Sendable {
    case remote
    case `default`
    case `static`
}

/// One key's resolved value, ready to log.
struct RemoteConfigLogEntry: Sendable, Equatable {
    let key: String
    let value: String
    let source: RemoteConfigValueSource
    /// False for a key Firebase returned that the app's catalogue doesn't declare (likely a name mismatch).
    var isInCatalogue: Bool = true
}

/// Pure formatting for the post-fetch log line, kept out of `FirebaseRemoteConfigService` so it is testable.
enum RemoteConfigLogFormatter {
    /// Lists only values served by Firebase; keys still on compiled defaults are summarised as a count.
    static func summary(_ entries: [RemoteConfigLogEntry]) -> String {
        let remote = entries.filter { $0.source == .remote }
        let defaultCount = entries.count - remote.count
        guard !remote.isEmpty else {
            return "Remote Config: no values from Firebase (\(defaultCount) keys using compiled defaults)"
        }
        let body = remote.map { "\($0.key)=\($0.value)\($0.isInCatalogue ? "" : " [not in app catalogue]")" }.joined(separator: ", ")
        return "Remote Config values from Firebase: \(body) (\(defaultCount) keys using compiled defaults)"
    }
}
