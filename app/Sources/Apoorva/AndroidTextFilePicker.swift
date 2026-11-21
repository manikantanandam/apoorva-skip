#if os(Android)
import Foundation
import SkipFuse
import ApoorvaModules

/// Opens Android's document picker through the Kotlin `FilePicker` (`Android/app/src/main/kotlin/FilePicker.kt`).
/// Swift closures can't be passed to Kotlin, so this starts the picker and polls until the Kotlin side has a result.
enum AndroidTextFilePicker {
    private static let pollNanoseconds: UInt64 = 200_000_000
    private static let maxPolls = 3_000  // about ten minutes

    static func make() -> TextFilePicker {
        TextFilePicker {
            guard let picker = try? AnyDynamicObject(forStaticsOfClassName: "apoorva.module.FilePicker") else { return nil }
            let started: Bool? = try? picker.launch()
            guard started == true else { return nil }
            for _ in 0..<maxPolls {
                try? await Task.sleep(nanoseconds: pollNanoseconds)
                if Task.isCancelled { return nil }
                let state: Int? = try? picker.state()
                switch state {
                case 1:
                    let text: String? = try? picker.text()
                    let name: String? = try? picker.fileName()
                    guard let text else { return nil }
                    return PickedTextFile(name: name ?? "import.csv", text: text)
                case 0:
                    continue
                default:
                    return nil
                }
            }
            return nil
        }
    }
}
#endif
