//
//  EverySecond.swift
//  ApoorvaModules
//

import SwiftUI

extension View {
    /// Calls `action` with the current date once a second while the view is on screen.
    /// A `.task` loop instead of `Timer.publish`/`onReceive`, so it needs no Combine (unavailable on Android).
    func everySecond(perform action: @escaping @MainActor (Date) -> Void) -> some View {
        task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await action(Date())
            }
        }
    }
}
