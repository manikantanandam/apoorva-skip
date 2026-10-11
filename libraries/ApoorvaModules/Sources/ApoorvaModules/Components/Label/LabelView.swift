//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 11/10/26.
//

import Foundation
import SwiftUI

public struct LabelView: View {
    
    private let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        Text(text)
            .font(.system(.headline))
    }
}
