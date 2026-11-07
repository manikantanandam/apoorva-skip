//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 10/10/26.
//

import Foundation
import SwiftUI

public enum CustomButtonAlignment {
    case horizontal
    case vertical
}

public struct CustomButton: View {
    
    let text: String
    let icon: ApoorvaIcon?
    let action: () -> Void
    let needLoader: Bool
    private let minHeight: CGFloat
    let backgroundColor: ApoorvaColor
    let textColor: ApoorvaColor
    let alignment: CustomButtonAlignment
    private let externalIsLoading: Binding<Bool>?
    @State private var internalIsLoading: Bool = false
    private var isLoading: Bool {
        get { externalIsLoading?.wrappedValue ?? internalIsLoading }
        nonmutating set {
            if let externalIsLoading {
                externalIsLoading.wrappedValue = newValue
            } else {
                internalIsLoading = newValue
            }
        }
    }

    public init(text: String,
                icon: ApoorvaIcon? = nil,
                needLoader: Bool = false,
                isLoading: Binding<Bool>? = nil,
                minHeight: CGFloat = 60,
                backgroundColor: ApoorvaColor = .systemBackGround,
                textColor: ApoorvaColor = .buttonTextColor,
                alignment: CustomButtonAlignment = .horizontal,
                action: @escaping () -> Void) {
        self.text = text
        self.icon = icon
        self.action = action
        self.needLoader = needLoader
        self.externalIsLoading = isLoading
        self.backgroundColor = backgroundColor
        self.minHeight = minHeight
        self.textColor = textColor
        self.alignment = alignment
    }
    
    public var body: some View {
        Group {
            switch alignment {
            case .horizontal:
                HStack {
                    content
                }
            case .vertical:
                VStack {
                    content
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .center)
        .background(backgroundColor.color)
        .onTapGesture {
            if needLoader {
                guard !isLoading else { return }
            }
            action()
        }
    }
    
    @ViewBuilder var content: some View {
        if isLoading && needLoader {
            CircularLoadingView()
        } else {
            if let icon {
                IconView(icon: icon, iconSize: 24, color: textColor.color)
            }
            Text(text)
                .foregroundStyle(textColor.color)
        }
    }
}
