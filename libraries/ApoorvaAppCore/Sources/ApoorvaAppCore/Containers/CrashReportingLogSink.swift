//
//  CrashReportingLogSink.swift
//  ApoorvaAppCore
//

import ManiLogger
import ApoorvaServices

/// Forwards warning+ log entries to the crash reporter's log, so they ride along on crash and
/// non-fatal reports. Keeps the crash-reporting provider out of `ManiLogger`.
struct CrashReportingLogSink: LogSink {
    let crashReportingService: CrashReportingServicing
    var minimumLevel: LogLevel = .warning

    func write(_ entry: LogEntry) {
        guard entry.level >= minimumLevel else { return }
        crashReportingService.log("\(entry.level.label) [\(entry.category.rawValue)] \(entry.message)")
    }
}
