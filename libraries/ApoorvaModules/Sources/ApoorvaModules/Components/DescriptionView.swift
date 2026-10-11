//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 11/10/26.
//

import SwiftUI

struct DescriptionView: View {
    let title: String
    let value: String
    public var body: some View {
        CardView() {
            HStack {
                LabelView(text: title)
                Spacer()
                LabelView(text: value)
            }
        }
    }
}
