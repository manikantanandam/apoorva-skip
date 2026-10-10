//
//  File.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 10/10/26.
//

import SwiftUI

struct IconView: View {
    
    let icon: ApoorvaIcon
    let iconSize: CGFloat
    let color: Color
    
    var body: some View {
        Image(systemName: icon.rawValue)
            .font(.system(size: iconSize))
            .foregroundStyle(color)
    }
}

#Preview {
    IconView(icon: .person, iconSize: 24, color: .red)
}
