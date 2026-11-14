//
//  AuthScreens.swift
//  ApoorvaModules
//
//  Designs 01–12: splash, demo, sign-in hub, phone OTP, email sign-in/register/verify/forgot,
//  Google chooser, link accounts.
//

import SwiftUI
import Combine
import ManiSwiftUIComponents
import ApoorvaModels

// MARK: - 01 Splash

public struct SplashView: View {
    @Environment(\.maniTheme) private var theme
    private let onGetStarted: () -> Void
    private let onDemo: () -> Void

    public init(onGetStarted: @escaping () -> Void, onDemo: @escaping () -> Void) {
        self.onGetStarted = onGetStarted
        self.onDemo = onDemo
    }

    public var body: some View {
        VStack(spacing: ManiSpacing.lg) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.accent.accent)
                    .frame(width: 88, height: 88)
                Text("A")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(theme.accent.on)
            }
            Text("Apoorva")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(theme.base.text)
            Text("Billing, beautifully simple")
                .font(theme.typography.body)
                .foregroundStyle(theme.base.textSecondary)
            Spacer()
            ManiButton("Get started", action: onGetStarted)
                .accessibilityIdentifier(AccessibilityID.Splash.getStarted)
            ManiButton("See a demo shop", kind: .outline, action: onDemo)
        }
        .padding(ManiSpacing.xl)
        .background(theme.base.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - 02 Demo shop

public struct DemoShopView: View {
    @State private var selection: Vertical = .fancy
    private let onTry: (Vertical) -> Void
    private let onStartOwn: () -> Void

    public init(onTry: @escaping (Vertical) -> Void, onStartOwn: @escaping () -> Void) {
        self.onTry = onTry
        self.onStartOwn = onStartOwn
    }

    public var body: some View {
        ScreenScroll {
            ManiEmptyState(icon: .sparkles, title: "See how Apoorva works",
                           message: "Try a sample shop with items, customers and bills. Nothing you do here is saved.")
            ManiPickList(options: Vertical.allCases.map {
                ManiPickOption(value: $0, title: sampleName(for: $0), subtitle: $0.title,
                               swatch: ThemeStore.swatchColor(for: $0.defaultAccent))
            }, selection: $selection)
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton("Try sample shop") { onTry(selection) }
                ManiButton("Start my own shop", kind: .outline, action: onStartOwn)
            }
        }
        .navigationTitle("Demo")
    }

    private func sampleName(for vertical: Vertical) -> String {
        switch vertical {
        case .kirana: "Sri Lakshmi Stores"
        case .fancy: "Glitz Gifts & Fancy"
        case .jewellery: "Swarna One Gram"
        case .parlour: "Glow Beauty Parlour"
        }
    }
}

// MARK: - 03 Sign-in hub

public struct SignInHubView: View {
    private let session: AppSession
    @Bindable private var viewModel: AuthFlowViewModel
    private let onGoogle: () -> Void
    private let onPhoneOTP: (String) -> Void
    private let onEmail: () -> Void
    private let onRegister: () -> Void
    private let onJoinWithCode: () -> Void

    public init(session: AppSession, viewModel: AuthFlowViewModel, onGoogle: @escaping () -> Void,
                onPhoneOTP: @escaping (String) -> Void, onEmail: @escaping () -> Void,
                onRegister: @escaping () -> Void, onJoinWithCode: @escaping () -> Void) {
        self.session = session
        self.viewModel = viewModel
        self.onGoogle = onGoogle
        self.onPhoneOTP = onPhoneOTP
        self.onEmail = onEmail
        self.onRegister = onRegister
        self.onJoinWithCode = onJoinWithCode
    }

    public var body: some View {
        ScreenScroll {
            ManiAppBar(title: "Welcome")
            ScreenSubtitle(text: "Sign in or create your shop account")

            if session.isOn(.authGoogle) {
                ManiProviderButton(provider: .google, title: "Continue with Google", action: onGoogle)
            }
            if session.isOn(.authPhoneOTP) {
                ScreenSubtitle(text: "or use your phone")
                ManiInputField(label: "Phone number", text: $viewModel.phone, placeholder: "+91 98480 12345", keyboard: .phone)
                ManiButton("Send OTP", isLoading: viewModel.isWorking) {
                    Task { if await viewModel.sendOTP() { onPhoneOTP(viewModel.phone) } }
                }
            }
            if session.isOn(.authEmailPassword) {
                ManiButton("Sign in with email", icon: .mail, kind: session.isOn(.authPhoneOTP) ? .outline : .primary, action: onEmail)
                    .accessibilityIdentifier(AccessibilityID.SignInHub.emailButton)
                if session.isOn(.authRegistrationsOpen) {
                    Button("New here? Create an account with email", action: onRegister)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            }
            Button("Have an invite code from your shop?", action: onJoinWithCode)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            if let error = viewModel.errorMessage {
                ManiNote(error, kind: .error)
            }
            ManiNote("Only the sign-in methods turned on for Apoorva are shown. Works offline after the first sign-in.")
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - 04 Phone OTP

public struct PhoneOTPView: View {
    @Bindable private var viewModel: AuthFlowViewModel
    @State private var now = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(viewModel: AuthFlowViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Enter the 6-digit code sent to \(viewModel.phone)")
            ManiCodeField(length: 6, code: viewModel.otp)
            let seconds = viewModel.secondsUntilResend
            Button(seconds > 0 ? "Resend code in 0:\(String(format: "%02d", seconds))" : "Resend code") {
                Task { _ = await viewModel.sendOTP() }
            }
            .disabled(seconds > 0)
            .frame(maxWidth: .infinity)
            ManiKeypad(showsDecimal: false) { key in
                viewModel.otp = key.apply(to: viewModel.otp, maxDecimals: 0, maxLength: 6)
            }
            if let error = viewModel.errorMessage {
                ManiNote(error, kind: .error)
            }
        } bottom: {
            ManiButton("Verify", isLoading: viewModel.isWorking, isEnabled: viewModel.otp.count == 6) {
                Task { _ = await viewModel.verifyOTP() }
            }
        }
        .navigationTitle("Verify phone")
        .onReceive(ticker) { now = $0 }
    }
}

// MARK: - 07 Email sign-in

public struct EmailSignInView: View {
    private let session: AppSession
    @Bindable private var viewModel: LoginViewModel
    private let onForgot: () -> Void
    private let onRegister: () -> Void
    private let onGoogle: () -> Void

    public init(session: AppSession, viewModel: LoginViewModel, onForgot: @escaping () -> Void,
                onRegister: @escaping () -> Void, onGoogle: @escaping () -> Void) {
        self.session = session
        self.viewModel = viewModel
        self.onForgot = onForgot
        self.onRegister = onRegister
        self.onGoogle = onGoogle
    }

    public var body: some View {
        ScreenScroll {
            ManiInputField(label: "Email", text: $viewModel.username, placeholder: "you@shop.in", keyboard: .email)
                .accessibilityIdentifier(AccessibilityID.EmailSignIn.email)
            ManiInputField(label: "Password", text: $viewModel.password, isSecure: true)
                .accessibilityIdentifier(AccessibilityID.EmailSignIn.password)
            Button("Forgot password?", action: onForgot)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .trailing)
            if let error = viewModel.errorMessage {
                ManiNote(error, kind: .error)
                    .accessibilityIdentifier(AccessibilityID.EmailSignIn.error)
            }
            ManiButton("Sign in", isLoading: viewModel.isLoggingIn, isEnabled: viewModel.isLoginEnabled) {
                viewModel.loginPressed()
            }
            .accessibilityIdentifier(AccessibilityID.EmailSignIn.signInButton)
            if session.isOn(.authGoogle) {
                ManiProviderButton(provider: .google, title: "Continue with Google", action: onGoogle)
            }
            if session.isOn(.authRegistrationsOpen) {
                Button("No account? Create one", action: onRegister)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Sign in")
    }
}

// MARK: - 08 Register

public struct RegisterView: View {
    private let session: AppSession
    @Bindable private var viewModel: AuthFlowViewModel
    private let onRegistered: () -> Void
    private let onGoogle: () -> Void

    public init(session: AppSession, viewModel: AuthFlowViewModel, onRegistered: @escaping () -> Void, onGoogle: @escaping () -> Void) {
        self.session = session
        self.viewModel = viewModel
        self.onRegistered = onRegistered
        self.onGoogle = onGoogle
    }

    public var body: some View {
        ScreenScroll {
            ManiInputField(label: "Your name", text: $viewModel.name, placeholder: "Kiran Reddy")
            ManiInputField(label: "Email", text: $viewModel.email, placeholder: "you@shop.in", keyboard: .email)
            ManiInputField(label: "Password", text: $viewModel.password, isSecure: true)
            if !viewModel.passwordStrength.isEmpty {
                ScreenSubtitle(text: viewModel.passwordStrength)
            }
            ManiCard {
                ManiToggleRow(title: "I agree to the terms and privacy policy", isOn: $viewModel.acceptedTerms)
            }
            if let error = viewModel.errorMessage {
                ManiNote(error, kind: .error)
            }
            ManiButton("Create account", isLoading: viewModel.isWorking, isEnabled: viewModel.canRegister) {
                Task { if await viewModel.register() { onRegistered() } }
            }
            if session.isOn(.authGoogle) {
                ManiProviderButton(provider: .google, title: "Sign up with Google", action: onGoogle)
            }
        }
        .navigationTitle("Create account")
    }
}

// MARK: - 09 Verify email

public struct VerifyEmailView: View {
    @Environment(\.openURL) private var openURL
    @Bindable private var viewModel: AuthFlowViewModel
    @State private var tick = Date()
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let email: String
    private let onSetUpShop: () -> Void
    private let onChangeEmail: () -> Void

    public init(viewModel: AuthFlowViewModel, email: String, onSetUpShop: @escaping () -> Void, onChangeEmail: @escaping () -> Void) {
        self.viewModel = viewModel
        self.email = email
        self.onSetUpShop = onSetUpShop
        self.onChangeEmail = onChangeEmail
    }

    public var body: some View {
        ScreenScroll {
            ManiEmptyState(icon: .mail, title: "Check your inbox",
                           message: "We sent a verification link to \(email). Tap it to confirm your email.")
            ManiButton("Open mail app", icon: .mail) {
                if let url = URL(string: "message://") { openURL(url) }
            }
            let seconds = viewModel.secondsUntilResend
            ManiButton(seconds > 0 ? "Resend link in 0:\(String(format: "%02d", seconds))" : "Resend link",
                       kind: .outline, isEnabled: seconds == 0) {
                Task { await viewModel.resendVerification() }
            }
            ManiButton("I've verified", kind: .secondary, isLoading: viewModel.isWorking) {
                Task { _ = await viewModel.checkVerified() }
            }
            if let info = viewModel.infoMessage {
                ManiNote(info, kind: .info)
            }
            if let error = viewModel.errorMessage {
                ManiNote(error, kind: .error)
            }
            ManiNote("You can set up your shop now. Syncing to the cloud starts once your email is verified.")
            Button("Wrong email? Use a different one", action: onChangeEmail)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        } bottom: {
            ManiButton("Set up my shop", action: onSetUpShop)
        }
        .navigationTitle("Verify email")
        .navigationBarBackButtonHidden()
        .onReceive(ticker) { tick = $0 }
    }
}

// MARK: - 10 Forgot password

public struct ForgotPasswordView: View {
    @Bindable private var viewModel: AuthFlowViewModel
    private let onBack: () -> Void

    public init(viewModel: AuthFlowViewModel, onBack: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onBack = onBack
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Enter your email and we'll send a link to reset your password.")
            ManiInputField(label: "Email", text: $viewModel.email, placeholder: "you@shop.in", keyboard: .email)
            ManiButton("Send reset link", isLoading: viewModel.isWorking, isEnabled: viewModel.isEmailValid) {
                Task { _ = await viewModel.sendPasswordReset() }
            }
            if let info = viewModel.infoMessage { ManiNote(info, kind: .info) }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
            ManiNote("Signed up with Google or your phone? You don't have a password — sign in that way instead.")
            ManiButton("Back to sign in", kind: .outline, action: onBack)
        }
        .navigationTitle("Forgot password")
    }
}

// MARK: - 11 Google account chooser

public struct GoogleChooserView: View {
    private let onUseEmail: () -> Void

    public init(onUseEmail: @escaping () -> Void) {
        self.onUseEmail = onUseEmail
    }

    public var body: some View {
        ScreenScroll {
            ManiEmptyState(icon: .globe, title: "Choose an account",
                           message: "Google sign-in opens your Google accounts here once it's switched on for this app.")
            ManiNote("Google sign-in isn't set up for this app yet. Use email for now.", kind: .warning)
            ManiButton("Use email instead", action: onUseEmail)
        }
        .navigationTitle("Google")
    }
}

// MARK: - 12 Link accounts

public struct LinkAccountsView: View {
    @Bindable private var viewModel: AuthFlowViewModel
    private let onUseDifferentAccount: () -> Void

    public init(viewModel: AuthFlowViewModel, onUseDifferentAccount: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onUseDifferentAccount = onUseDifferentAccount
    }

    public var body: some View {
        ScreenScroll {
            ManiEmptyState(icon: .link, title: "Account already exists",
                           message: "\(viewModel.email) already has an Apoorva account. Enter its password to sign in and link both ways of signing in.")
            ManiInputField(label: "Password", text: $viewModel.password, isSecure: true)
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
            ManiButton("Link & sign in", isLoading: viewModel.isWorking, isEnabled: !viewModel.password.isEmpty) {
                Task { _ = await viewModel.signInToLink() }
            }
            ManiButton("Use a different account", kind: .outline, action: onUseDifferentAccount)
        }
        .navigationTitle("Link accounts")
    }
}
