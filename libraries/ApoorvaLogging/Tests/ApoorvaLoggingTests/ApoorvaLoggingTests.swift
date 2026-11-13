//
//  ApoorvaLoggingTests.swift
//  ApoorvaLogging
//

import Foundation
import Testing
@testable import ApoorvaLogging

private func entry(_ message: String, level: LogLevel = .info) -> LogEntry {
    LogEntry(level: level, category: .app, message: message, sessionId: "s")
}

@Suite struct LogBufferTests {
    @Test func dropsOldestBeyondCapacity() {
        let buffer = LogBuffer(capacity: 2)
        buffer.write(entry("a"))
        buffer.write(entry("b"))
        buffer.write(entry("c"))
        #expect(buffer.entries.map(\.message) == ["b", "c"])
        buffer.clear()
        #expect(buffer.entries.isEmpty)
    }

    @Test func shareableTextUsesFormattedLines() {
        let buffer = LogBuffer()
        buffer.write(entry("hello", level: .error))
        #expect(buffer.shareableText.hasSuffix("ERROR [app] hello"))
    }
}

@Suite struct AppLoggerTests {
    @Test func fansOutToAllSinksAboveMinimumLevel() {
        let registry = LogSinks()
        let first = LogBuffer()
        let second = LogBuffer()
        registry.configure(sinks: [first, second], minimumLevel: .info)
        let logger = AppLogger(category: .sync, registry: registry)

        logger.debug("dropped")
        logger.info("kept")
        logger.error("also kept")

        #expect(first.entries.map(\.message) == ["kept", "also kept"])
        #expect(second.entries.count == 2)
        #expect(first.entries.allSatisfy { $0.category == .sync && $0.sessionId == registry.sessionId })
    }
}

@Suite struct FileLogSinkTests {
    private func makeSink(maxFileSize: Int) -> FileLogSink {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return FileLogSink(directory: directory, maxFileSize: maxFileSize)
    }

    @Test func appendsLinesToCurrentFile() {
        let sink = makeSink(maxFileSize: 1_000_000)
        sink.write(entry("one"))
        sink.write(entry("two"))
        let contents = sink.contents()
        #expect(contents.contains("one"))
        #expect(contents.contains("two"))
        #expect(sink.logFiles == [sink.currentFileURL])
    }

    @Test func rotatesWhenFileExceedsMaxSize() {
        let sink = makeSink(maxFileSize: 10)
        sink.write(entry("first line"))
        sink.write(entry("second line"))
        sink.flush()
        #expect(FileManager.default.fileExists(atPath: sink.previousFileURL.path))
        #expect(sink.contents().contains("second line"))
    }

    @Test func clearRemovesFiles() {
        let sink = makeSink(maxFileSize: 1_000_000)
        sink.write(entry("x"))
        sink.clear()
        #expect(sink.logFiles.isEmpty)
    }
}
