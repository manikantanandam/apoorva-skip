//
//  SwiftUIView.swift
//  ApoorvaAppCore
//
//  Created by Manikanta Nandam on 04/10/26.
//

import SwiftUI
import ApoorvaModules

@MainActor
@Observable
class MainViewModel {
    enum State {
        case login(LoginViewModel)
        case pos(POSViewModel)
        case home(AppContainer)
        case loading
    }
    
    var state: State = .loading
    
    let appContainer: AppContainer = AppContainer()
    
    init() {
        Task {
            await checkForLoggedInUser()
        }
    }
    
    func checkForLoggedInUser() async {
        let userService = appContainer.servicesContainer.userService
        for await user in userService.userSessionStream {
            if user == nil {
                state = .login(appContainer.modulesContainer.makeLoginViewModel())
            } else {
                state = .home(appContainer)
            }

        }
    }
}

public struct MainView: View {
    
    @State var viewModel: MainViewModel = MainViewModel()
    
    public init() {}
    
    public var body: some View {
        switch viewModel.state {
        case .loading:
            Text("Loading")
        case .home(let container):
            HomeView(container: container)
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
