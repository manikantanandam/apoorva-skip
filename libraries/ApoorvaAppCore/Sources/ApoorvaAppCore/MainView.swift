//
//  SwiftUIView.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI
import ApoorvaUI

@MainActor
@Observable
class MainViewModel {
    enum State {
        case login(LoginViewModel)
        case pos(POSViewModel)
        case home
        case loading
    }
    
    var state: State = .loading
    
    private let appContainer: AppContainer = AppContainer()
    
    init() {
        Task {
            await checkForLoggedInUser()
        }
    }
    
    func checkForLoggedInUser() async {
        let authService = appContainer.core.authService
        for await user in authService.currentUserStream {
            if user == nil {
                state = .login(appContainer.login.makeLoginViewModel())
                print("No User logged in")
            } else {
                state = .pos(appContainer.pos.makeLoginViewModel())
                print("Received: \(user!)")
            }

        }
        print("Stream finished!")
        
    }
    
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
        case .login(let viewModel):
            LoginView(viewModel: viewModel)
        case .pos(let viewModel):
            POSView(viewModel: viewModel)
            
        }
    }
}

#Preview {
    MainView()
}
