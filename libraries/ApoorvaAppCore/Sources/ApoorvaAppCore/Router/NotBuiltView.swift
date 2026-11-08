import SwiftUI

/// Generic destination for any screen in the frozen v1 design that hasn't been
/// built yet. Lets every Route case resolve to a real, navigable destination;
/// a future PR only needs to replace the call site with the real screen.
struct NotBuiltView: View {
    let screen: PlaceholderScreen

    init(_ screen: PlaceholderScreen) {
        self.screen = screen
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hammer")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(screen.title)
                .font(.headline)
            Text("Not built yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(screen.title)
    }
}
