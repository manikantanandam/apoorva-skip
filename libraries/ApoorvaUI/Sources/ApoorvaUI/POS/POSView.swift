//
//  File.swift
//  ApoorvaUI
//
//  Created by Manikanta Nandam on 07/10/26.
//

import SwiftUI

public struct POSView: View {
    
    // 1. Inject the ViewModel
    @Bindable private var viewModel: POSViewModel
    
    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        Text("POS View")
        
        Button {
            viewModel.logoutPressed()
        } label: {
            Text("Log out")
        }

    }
    
    
}
