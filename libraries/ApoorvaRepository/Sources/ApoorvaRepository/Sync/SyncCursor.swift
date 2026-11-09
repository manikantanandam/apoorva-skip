//
//  SyncCursor.swift
//  ApoorvaRepository
//

import Foundation

/// Sync cursor helpers shared by the delta-sync repositories.
enum SyncCursor {
    /// Re-read this far behind the stored cursor. Writes from devices whose clocks lag, or that
    /// arrive slightly out of order, still get picked up. Re-reads are harmless (upserts).
    static let overlap: TimeInterval = 10 * 60

    /// The date to query from, given the stored cursor.
    static func queryStart(from stored: TimeInterval) -> Date {
        Date(timeIntervalSince1970: max(stored - overlap, 0))
    }

    /// The newest of every candidate date across the fetched records, or nil if there are none.
    static func latest(_ dates: [Date?]) -> Date? {
        dates.compactMap { $0 }.max()
    }
}
