//
//  SwiftUIView.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI
import ApoorvaUI
import ApoorvaViewModel

enum MainRoute: String, Route {
    case login
    case home
}

@Observable
class MainViewModel {
    enum State {
        case login
        case home
        case loading
    }
    
    var state: State = .loading
}

public struct MainView: View {
    
    
    @State var viewModel: MainViewModel = MainViewModel()
    
    public init() {}
    
    public var body: some View {
        switch viewModel.state {
        case .loading:
            Text("Loading")
        case .home:
            HomeView()
        case .login:
            Text("LoginView")
        }
    }
}

#Preview {
    MainView()
}
