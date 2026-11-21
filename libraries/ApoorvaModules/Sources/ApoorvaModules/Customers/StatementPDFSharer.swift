//
//  StatementPDFSharer.swift
//  ApoorvaModules
//

import SwiftUI
import ApoorvaModels

/// Draws a statement to a PDF and opens the system share sheet. SkipSwiftUI has no `ImageRenderer`, so the Android app
/// injects one (see `AndroidStatementPDF`); iOS renders `StatementCard` itself and never reads this.
public struct StatementPDFSharer: Sendable {
    /// Takes the plain-text payload built by `StatementPDFPayload` and a file name; returns false if sharing couldn't start.
    public var share: @MainActor @Sendable (_ payload: String, _ fileName: String) -> Bool

    public init(share: @escaping @MainActor @Sendable (_ payload: String, _ fileName: String) -> Bool) {
        self.share = share
    }
}

private struct StatementPDFSharerKey: EnvironmentKey {
    static let defaultValue: StatementPDFSharer? = nil
}

public extension EnvironmentValues {
    var statementPDFSharer: StatementPDFSharer? {
        get { self[StatementPDFSharerKey.self] }
        set { self[StatementPDFSharerKey.self] = newValue }
    }
}

/// One line per row, `style<TAB>left<TAB>right`: h shop name, s subtitle, m muted, r row, b bold row, d divider.
enum StatementPDFPayload {
    static func make(shopName: String, customerName: String, range: (start: Date, end: Date), statement: CustomerStatement) -> String {
        var lines: [String] = []
        func add(_ style: String, _ left: String = "", _ right: String = "") {
            lines.append([style, clean(left), clean(right)].joined(separator: "\t"))
        }
        add("h", shopName)
        add("s", "Statement · \(customerName)")
        add("m", "\(range.start.shortDay) – \(range.end.shortDay)")
        add("d")
        add("r", "Opening balance", Money.format(statement.opening))
        for entry in statement.entries {
            add("r", "\(entry.createdAt.shortDay)  \(entry.note ?? entry.kind.rawValue.capitalized)",
                (entry.amount >= 0 ? "+" : "−") + Money.format(abs(entry.amount)))
        }
        add("d")
        add("r", "Bills", "+" + Money.format(statement.bills))
        add("r", "Payments", "−" + Money.format(statement.payments))
        add("b", "Closing balance", Money.format(statement.closing))
        return lines.joined(separator: "\n")
    }

    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
    }
}
