//
//  File.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import Foundation

/// A screen from the frozen v1 design (docs/04-ui-design.md, designs/README.md) that
/// hasn't been built yet. Route enums route their not-yet-built cases to a
/// `NotBuiltView(PlaceholderScreen(...))` so the full navigation graph is wired
/// without writing that screen's content up front.
struct PlaceholderScreen: Hashable, Identifiable {
    let title: String
    var id: String { title }

    init(_ title: String) {
        self.title = title
    }
}
