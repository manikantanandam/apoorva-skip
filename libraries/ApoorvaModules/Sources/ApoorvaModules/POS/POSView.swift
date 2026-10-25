//
//  File.swift
//  ApoorvaModules
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
        NavigationStack {
            ScrollView {
                VStack {
                    IconTextField(
                        text: $viewModel.customerName,
                        placeholder: "Customer Name",
                        icon: .person
                    )
                    
                    IconTextField(
                        text: $viewModel.customerPhoneNumber,
                        placeholder: "Phone Number",
                        icon: .phone
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
