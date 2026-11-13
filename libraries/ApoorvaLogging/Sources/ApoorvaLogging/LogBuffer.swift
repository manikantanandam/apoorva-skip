//
//  LogBuffer.swift
//  ApoorvaLogging
//

import Foundation

/// In-memory ring buffer of recent log entries for the in-app log viewer.
public final class LogBuffer: LogSink, @unchecked Sendable {
    private let capacity: Int
    private let lock = NSLock()
    private var items: [LogEntry] = []

    public init(capacity: Int = 500) {
        self.capacity = max(0, capacity)
    }

    public func write(_ entry: LogEntry) {
        lock.lock(); defer { lock.unlock() }
        items.append(entry)
        if items.count > capacity {
            items.removeFirst(items.count - capacity)
        }
    }

    public var entries: [LogEntry] {
        lock.lock(); defer { lock.unlock() }
        return items
    }

    public var shareableText: String {
        entries.map(\.formatted).joined(separator: "\n")
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        items.removeAll()
    }
}
