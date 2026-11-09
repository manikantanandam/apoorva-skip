import SwiftUI
import ApoorvaModules

struct OnboardingCoordinatorView: View {
    @Bindable var coordinator: OnboardingCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            destination(for: coordinator.root)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: OnboardingRoute) -> some View {
        switch route {
        case .signInHub, .splash:
            LoginView(viewModel: coordinator.container.modulesContainer.makeLoginViewModel())
        case .demoShop:
            NotBuiltView(PlaceholderScreen("Demo shop"))
        case .otp:
            NotBuiltView(PlaceholderScreen("Verify phone"))
        case .emailSignIn:
            NotBuiltView(PlaceholderScreen("Email sign-in"))
        case .register:
            NotBuiltView(PlaceholderScreen("Register"))
        case .verifyEmail:
            NotBuiltView(PlaceholderScreen("Verify email"))
        case .forgotPassword:
            NotBuiltView(PlaceholderScreen("Forgot password"))
        case .googleChooser:
            NotBuiltView(PlaceholderScreen("Google chooser"))
        case .linkAccounts:
            NotBuiltView(PlaceholderScreen("Link accounts"))
        case .chooseVertical:
            NotBuiltView(PlaceholderScreen("Choose vertical"))
        case .shopSetup:
            NotBuiltView(PlaceholderScreen("Shop setup"))
        case .pickLook:
            NotBuiltView(PlaceholderScreen("Pick look"))
        case .firstRunGuide:
            NotBuiltView(PlaceholderScreen("First-run guide"))
        case .openingBalances:
            NotBuiltView(PlaceholderScreen("Opening balances"))
        case .staffJoin:
            NotBuiltView(PlaceholderScreen("Staff join"))
        case .pinSwitch:
            NotBuiltView(PlaceholderScreen("PIN switch"))
        }
    }
}
