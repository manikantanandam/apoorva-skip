//
//  FileLogSink.swift
//  ApoorvaLogging
//

import Foundation

/// Appends formatted entries to `current.log`, rotating to `previous.log` once `maxFileSize` is
/// exceeded (so at most two files are kept). Writes happen on a private serial queue.
/// These files are the source for exporting logs (share sheet now, remote upload later).
public final class FileLogSink: LogSink, @unchecked Sendable {
    public let directory: URL
    private let maxFileSize: Int
    private let queue = DispatchQueue(label: "apoorva.logging.file", qos: .utility)

    public var currentFileURL: URL { directory.appendingPathComponent("current.log") }
    public var previousFileURL: URL { directory.appendingPathComponent("previous.log") }

    public init(directory: URL, maxFileSize: Int = 1_000_000) {
        self.directory = directory
        self.maxFileSize = maxFileSize
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// `Application Support/Logs`
    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Logs", isDirectory: true)
    }

    public func write(_ entry: LogEntry) {
        let line = entry.formatted + "\n"
        queue.async { [self] in append(line) }
    }

    /// Blocks until queued writes are on disk.
    public func flush() {
        queue.sync {}
    }

    /// Existing log files, oldest first.
    public var logFiles: [URL] {
        flush()
        return [previousFileURL, currentFileURL].filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Both files concatenated, oldest first.
    public func contents() -> String {
        logFiles.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined()
    }

    public func clear() {
        queue.sync {
            try? FileManager.default.removeItem(at: currentFileURL)
            try? FileManager.default.removeItem(at: previousFileURL)
        }
    }

    private func append(_ line: String) {
        guard let data = line.data(using: .utf8) else { return }
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: currentFileURL.path) {
            fileManager.createFile(atPath: currentFileURL.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: currentFileURL) else { return }
        let size = (try? handle.seekToEnd()) ?? 0
        try? handle.write(contentsOf: data)
        try? handle.close()
        if Int(size) + data.count > maxFileSize {
            rotate()
        }
    }

    private func rotate() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: previousFileURL)
        try? fileManager.moveItem(at: currentFileURL, to: previousFileURL)
    }
}
