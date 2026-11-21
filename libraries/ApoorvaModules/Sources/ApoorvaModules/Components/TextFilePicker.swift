//
//  TextFilePicker.swift
//  ApoorvaModules
//

import SwiftUI
#if !os(Android)
import UniformTypeIdentifiers
#endif

/// A text file the user picked (CSV imports).
public struct PickedTextFile: Sendable {
    public let name: String
    public let text: String

    public init(name: String, text: String) {
        self.name = name
        self.text = text
    }
}

/// Opens the system document picker and returns the chosen file's text, or `nil` if the user cancelled.
/// SkipSwiftUI has no `fileImporter`, so the Android app injects one through the environment (see `AndroidTextFilePicker`);
/// iOS uses `fileImporter` directly and never reads this.
public struct TextFilePicker: Sendable {
    public var pick: @MainActor @Sendable () async -> PickedTextFile?

    public init(pick: @escaping @MainActor @Sendable () async -> PickedTextFile?) {
        self.pick = pick
    }
}

private struct TextFilePickerKey: EnvironmentKey {
    static let defaultValue: TextFilePicker? = nil
}

public extension EnvironmentValues {
    var textFilePicker: TextFilePicker? {
        get { self[TextFilePickerKey.self] }
        set { self[TextFilePickerKey.self] = newValue }
    }
}

extension View {
    /// Presents a CSV/text file picker when `isPresented` becomes true: `fileImporter` on iOS, the injected picker on Android.
    func textFileImporter(isPresented: Binding<Bool>, onFailure: @escaping () -> Void = {},
                          onPick: @escaping (PickedTextFile) -> Void) -> some View {
        modifier(TextFileImporter(isPresented: isPresented, onFailure: onFailure, onPick: onPick))
    }
}

private struct TextFileImporter: ViewModifier {
    @Environment(\.textFilePicker) private var picker
    @Binding var isPresented: Bool
    let onFailure: () -> Void
    let onPick: (PickedTextFile) -> Void

    func body(content: Content) -> some View {
        #if os(Android)
        content.onChange(of: isPresented) { _, presented in
            guard presented else { return }
            isPresented = false
            guard let picker else {
                onFailure()
                return
            }
            Task { @MainActor in
                if let file = await picker.pick() { onPick(file) }
            }
        }
        #else
        content.fileImporter(isPresented: $isPresented, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                onPick(PickedTextFile(name: url.lastPathComponent, text: text))
            } else {
                onFailure()
            }
        }
        #endif
    }
}
