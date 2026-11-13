//
//  LogEntry.swift
//  ApoorvaLogging
//

import Foundation

public enum LogLevel: Int, Sendable, CaseIterable, Comparable, Codable {
    case debug, info, warning, error

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    public var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }
}

/// Matches the categories in docs/06 §4, plus `app`/`config` for launch and Remote Config.
public enum LogCategory: String, Sendable, CaseIterable, Codable {
    case storage, sync, auth, network, ui, app, config
}

public struct LogEntry: Sendable, Equatable, Codable {
    public let date: Date
    public let level: LogLevel
    public let category: LogCategory
    public let message: String
    /// Per-launch id, so lines from one session can be correlated with analytics/crash reports.
    public let sessionId: String

    public init(date: Date = Date(), level: LogLevel, category: LogCategory, message: String, sessionId: String) {
        self.date = date
        self.level = level
        self.category = category
        self.message = message
        self.sessionId = sessionId
    }

    /// `2026-11-13T10:00:00.000Z ERROR [sync] message`
    public var formatted: String {
        "\(date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: true))) \(level.label) [\(category.rawValue)] \(message)"
    }
}

/// Destination for log entries (in-memory buffer, file, crash reporter, …).
public protocol LogSink: Sendable {
    func write(_ entry: LogEntry)
}
