import SwiftUI
import ApoorvaModules
import ApoorvaModels

struct OnboardingCoordinatorView: View {
    @Bindable var coordinator: OnboardingCoordinator

    /// Shared across the auth screens and the three setup steps, so typed values survive back/forward.
    @State private var authFlow: AuthFlowViewModel
    @State private var login: LoginViewModel
    @State private var shopSetup: ShopSetupViewModel

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
        let modules = coordinator.container.modulesContainer
        let session = coordinator.container.appSession
        _authFlow = State(initialValue: modules.makeAuthFlowViewModel())
        _login = State(initialValue: modules.makeLoginViewModel())
        _shopSetup = State(initialValue: modules.makeShopSetupViewModel(trialDays: { session.platform.trialDays }))
    }

    private var container: AppContainer { coordinator.container }
    private var session: AppSession { container.appSession }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            destination(for: coordinator.root)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    destination(for: route)
                }
        }
        .onAppear {
            login.onNeedsLinking = { email in
                authFlow.email = email
                coordinator.push(.linkAccounts(email: email))
            }
        }
    }

    @ViewBuilder
    private func destination(for route: OnboardingRoute) -> some View {
        switch route {
        case .splash:
            SplashView(onGetStarted: { coordinator.push(.signInHub) })
        case .signInHub, .emailSignIn:
            SignInHubView(session: session, viewModel: authFlow, login: login,
                          onGoogle: { coordinator.push(.googleChooser) },
                          onPhoneOTP: { phone in coordinator.push(.otp(phone: phone)) },
                          onForgot: {
                              authFlow.email = login.username
                              coordinator.push(.forgotPassword)
                          },
                          onRegister: { coordinator.push(.register) })
        case .otp:
            PhoneOTPView(viewModel: authFlow)
        case .register:
            RegisterView(session: session, viewModel: authFlow,
                         onRegistered: { coordinator.push(.verifyEmail) },
                         onGoogle: { coordinator.push(.googleChooser) })
        case .verifyEmail:
            VerifyEmailView(viewModel: authFlow,
                            email: container.servicesContainer.authService.currentAccount?.email ?? authFlow.email,
                            onSetUpShop: { coordinator.push(.chooseVertical) },
                            onChangeEmail: {
                                try? container.servicesContainer.authService.logout()
                            })
        case .forgotPassword:
            ForgotPasswordView(viewModel: authFlow, onBack: { coordinator.pop() })
        case .googleChooser:
            GoogleChooserView(onUseEmail: { coordinator.push(.emailSignIn) })
        case .linkAccounts:
            LinkAccountsView(viewModel: authFlow, onUseDifferentAccount: { coordinator.popToRoot() })
        case .chooseVertical:
            ChooseVerticalView(viewModel: shopSetup, invitations: container.modulesContainer.invitationsViewModel,
                               onContinue: { coordinator.push(.shopSetup) })
        case .shopSetup:
            ShopSetupView(viewModel: shopSetup, onContinue: { coordinator.push(.pickLook) })
        case .pickLook:
            // Creating the shop writes the owner profile; the session listener then opens Home,
            // where the first-run guide leads to opening balances (step 4).
            PickLookView(viewModel: shopSetup, themeStore: container.themeStore, onFinished: {})
        case .firstRunGuide, .openingBalances:
            OpeningBalancesView(viewModel: container.modulesContainer.makeOpeningBalancesViewModel(session: session),
                                onDone: { coordinator.popToRoot() })
        case .pinSwitch:
            PinSwitchView(viewModel: container.modulesContainer.makePinSwitchViewModel(session: session),
                          onSwitched: { coordinator.pop() })
        }
    }
}
