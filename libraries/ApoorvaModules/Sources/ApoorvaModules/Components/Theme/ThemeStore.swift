import ManiSwiftUIComponents
import SwiftUI

/// Owns the app's currently-resolved theme + style and exposes them for
/// `.maniTheme(...)` at the app root.
///
/// NOTE: this does not yet implement the org-lock → user-preference →
/// store → org → vertical-default resolution order from docs/04-ui-design.md
/// — that needs Organization/Store/User data from ApoorvaRepository. Until
/// then this defaults to Apoorva Ink / Clean.
@MainActor
@Observable
public final class ThemeStore {
    public private(set) var theme: any ManiTheme
    public private(set) var style: ManiStyle

    public init(theme: any ManiTheme = ManiAccentTheme.apoorvaInk, style: ManiStyle = .clean) {
        self.theme = theme
        self.style = style
    }

    public func update(theme: any ManiTheme, style: ManiStyle) {
        self.theme = theme
        self.style = style
    }
}

public extension View {
    /// Convenience for applying a `ThemeStore`'s current resolution.
    /// Type-erased because `store.theme` is an existential whose concrete
    /// type can change at runtime as the store's resolution updates.
    func maniTheme(from store: ThemeStore) -> AnyView {
        AnyView(maniThemeErased(store.theme, style: store.style))
    }
}
