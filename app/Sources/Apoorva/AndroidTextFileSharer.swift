#if os(Android)
import Foundation
import SkipFuse
import ApoorvaModules

/// Shares a text file through the Kotlin `StatementPdf.shareText` (`Android/app/src/main/kotlin/StatementPdf.kt`).
enum AndroidTextFileSharer {
    static func make() -> TextFileSharer {
        TextFileSharer { content, fileName, mimeType in
            guard let sharer = try? AnyDynamicObject(forStaticsOfClassName: "apoorva.module.StatementPdf") else { return false }
            let shared: Bool? = try? sharer.shareText(content, fileName, mimeType)
            return shared == true
        }
    }
}
#endif
