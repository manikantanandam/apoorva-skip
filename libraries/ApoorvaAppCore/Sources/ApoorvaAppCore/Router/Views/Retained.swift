import SwiftUI

/// Keeps a view model alive across parent redraws. Navigation destinations are rebuilt whenever
/// the coordinator view's state changes; making the view model inline would reset the screen.
struct Retained<Model: AnyObject, Content: View>: View {
    @State private var model: Model
    private let content: (Model) -> Content

    init(_ make: @autoclosure () -> Model, @ViewBuilder content: @escaping (Model) -> Content) {
        _model = State(initialValue: make())
        self.content = content
    }

    var body: some View {
        content(model)
    }
}
