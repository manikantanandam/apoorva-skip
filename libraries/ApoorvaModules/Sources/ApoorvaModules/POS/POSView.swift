//
//  File.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 07/10/26.
//

import SwiftUI
import ManiSwiftUIComponents

public struct POSView: View {

    // 1. Inject the ViewModel
    @Bindable private var viewModel: POSViewModel

    public init(viewModel: POSViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ManiSpacing.md) {
                    ManiInputField(
                        label: "Customer name",
                        text: $viewModel.customerName,
                        placeholder: "e.g. Priya"
                    )

                    ManiInputField(
                        label: "Phone number",
                        text: $viewModel.customerPhoneNumber,
                        placeholder: "e.g. 98765 43210",
                        keyboard: .phone
                    )

                    QuickItemsView(items: viewModel.items)
                    
                    SelectedCartItemsView(items: viewModel.items)
                    
                    
                    
        //            CustomButton(text: "Logout", backgroundColor: .orange) {
        //                viewModel.logoutPressed()
        //            }
                    Spacer()
                }
                .padding(16)
            }
            
        }
        
    }
    
    
}
