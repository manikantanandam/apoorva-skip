//
//  AuthFlowViewModel.swift
//  ApoorvaModules
//

import Foundation
import ApoorvaModels
import ApoorvaServices

/// Register, verify email, forgot password, link accounts and the phone/Google entry points
/// (designs 03–12). Navigation happens in the coordinator; this only does the work.
@MainActor
@Observable
public final class AuthFlowViewModel {
    public var name = ""
    public var email = ""
    public var password = ""
    public var phone = ""
    public var otp = ""
    public var acceptedTerms = false
    public var isWorking = false
    public var errorMessage: String?
    public var infoMessage: String?
    public private(set) var resendAvailableAt: Date?

    private let authService: AuthServicing

    public init(authService: AuthServicing) {
        self.authService = authService
    }

    // MARK: Validation

    public var isEmailValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count >= 5
    }

    public var passwordStrength: String {
        switch password.count {
        case 0: ""
        case 1..<6: "Too short — use at least 6 characters"
        case 6..<10: password.rangeOfCharacter(from: .decimalDigits) == nil ? "Okay — add a number to make it stronger" : "Good"
        default: "Strong"
        }
    }

    public var canRegister: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && isEmailValid && password.count >= 6 && acceptedTerms
    }

    public var isPhoneValid: Bool {
        phone.filter(\.isNumber).count >= 10
    }

    public var secondsUntilResend: Int {
        guard let resendAvailableAt else { return 0 }
        return max(0, Int(resendAvailableAt.timeIntervalSinceNow.rounded(.up)))
    }

    // MARK: Actions

    public func register() async -> Bool {
        guard canRegister else { return false }
        return await run {
            try await self.authService.register(name: self.name.trimmingCharacters(in: .whitespaces),
                                                email: self.email.trimmingCharacters(in: .whitespaces),
                                                password: self.password)
            self.resendAvailableAt = Date().addingTimeInterval(45)
        }
    }

    public func resendVerification() async {
        guard secondsUntilResend == 0 else { return }
        _ = await run {
            try await self.authService.sendEmailVerification()
            self.resendAvailableAt = Date().addingTimeInterval(45)
            self.infoMessage = "We sent a new link."
        }
    }

    /// Returns true once the email is verified.
    public func checkVerified() async -> Bool {
        var verified = false
        _ = await run {
            verified = try await self.authService.reloadAccount()?.isEmailVerified ?? false
            if !verified { self.infoMessage = "Not verified yet. Tap the link in your email, then try again." }
        }
        return verified
    }

    public func sendPasswordReset() async -> Bool {
        guard isEmailValid else {
            errorMessage = "Enter the email you signed up with."
            return false
        }
        return await run {
            try await self.authService.sendPasswordReset(email: self.email.trimmingCharacters(in: .whitespaces))
            self.infoMessage = "Check your inbox for a reset link."
        }
    }

    /// Signs in to the existing email account so its other sign-in method can be linked later.
    public func signInToLink() async -> Bool {
        guard !password.isEmpty else { return false }
        return await run {
            try await self.authService.login(email: self.email, password: self.password)
        }
    }

    public func sendOTP() async -> Bool {
        guard isPhoneValid else {
            errorMessage = "Enter a 10-digit phone number."
            return false
        }
        resendAvailableAt = Date().addingTimeInterval(24)
        return true
    }

    /// Phone sign-in needs Firebase phone auth configured; until then this explains why.
    public func verifyOTP() async -> Bool {
        errorMessage = "Phone sign-in isn't set up for this app yet. Use email for now."
        return false
    }

    public func clearMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    private func run(_ work: @escaping () async throws -> Void) async -> Bool {
        clearMessages()
        isWorking = true
        defer { isWorking = false }
        do {
            try await work()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
