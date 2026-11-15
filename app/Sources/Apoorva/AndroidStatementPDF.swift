#if os(Android)
import Foundation
import SkipFuse
import ApoorvaModules

/// Draws the statement PDF and opens the Android share sheet through the Kotlin `StatementPdf`
/// (`Android/app/src/main/kotlin/StatementPdf.kt`).
enum AndroidStatementPDF {
    static func make() -> StatementPDFSharer {
        StatementPDFSharer { payload, fileName in
            guard let pdf = try? AnyDynamicObject(forStaticsOfClassName: "apoorva.module.StatementPdf") else { return false }
            let shared: Bool? = try? pdf.share(payload, fileName)
            return shared == true
        }
    }
}
#endif
