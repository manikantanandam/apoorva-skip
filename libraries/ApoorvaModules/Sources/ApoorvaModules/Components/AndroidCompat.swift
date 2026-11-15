//
//  AndroidCompat.swift
//  ApoorvaModules
//

import SwiftUI

// SkipSwiftUI (Android) declares `strokeBorder` ambiguously and lacks `monospacedDigit()` and `contentShape`.
// See docs/decisions/android-readiness.md for the full list of iOS/Android differences.

extension InsettableShape {
    /// `strokeBorder` on Apple platforms; a centred `stroke` on Android.
    func appBorder<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1) -> some View {
        #if os(Android)
        stroke(content, lineWidth: lineWidth).padding(lineWidth / 2)  // Shrinks the shape by half a line so the stroke sits inside, like strokeBorder.
        #else
        strokeBorder(content, lineWidth: lineWidth)
        #endif
    }
}

#if os(Android)
extension Font {
    func monospacedDigit() -> Font { self }
}

extension View {
    /// Near-transparent fill so empty areas of a row are tappable, as `contentShape` does on iOS (the shape itself is ignored).
    func contentShape<S: Shape>(_ shape: S) -> some View { background(Color.white.opacity(0.001)) }

    /// No-op: see `Grid` below.
    func gridColumnAlignment(_ guide: HorizontalAlignment) -> some View { self }
}

/// SkipSwiftUI has no `Grid`/`GridRow`. These stack rows vertically, so columns don't line up across rows.
struct Grid<Content: View>: View {
    private let verticalSpacing: CGFloat?
    private let content: Content

    init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil,
         @ViewBuilder content: () -> Content) {
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: verticalSpacing) { content }
    }
}

struct GridRow<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 6) { content }
    }
}
#endif
