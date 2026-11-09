//
//  StaffScreens.swift
//  ApoorvaModules
//
//  Design 05 (join a shop from an invite) and 06 (PIN switch on shared phones).
//

import SwiftUI
import ManiSwiftUIComponents
import ApoorvaModels
import ApoorvaServices
import ApoorvaRepository

// MARK: - 05 Staff join

@MainActor
@Observable
public final class StaffJoinViewModel {
    public var code: String
    public var name = ""
    public private(set) var invite: Invite?
    public var isWorking = false
    public var errorMessage: String?

    private let setupService: OrganizationSetupServicing
    private let authService: AuthServicing
    private let currentOrgs: () -> [OrganizationSnapshot]

    public init(code: String, setupService: OrganizationSetupServicing, authService: AuthServicing,
                currentOrgs: @escaping () -> [OrganizationSnapshot] = { [] }) {
        self.code = code
        self.setupService = setupService
        self.authService = authService
        self.currentOrgs = currentOrgs
    }

    public var isSignedIn: Bool { authService.currentAccount != nil }

    public func load() async {
        let token = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard token.count >= 6 else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            guard let found = try await setupService.fetchInvite(token: token) else {
                errorMessage = "We couldn't find that invite. Check the code with your shop owner."
                invite = nil
                return
            }
            if found.isAccepted {
                errorMessage = "This invite has already been used."
            } else if found.isExpired {
                errorMessage = "This invite has expired. Ask your owner to send a new one."
            }
            invite = found
            if name.isEmpty { name = found.name }
        } catch {
            errorMessage = "Couldn't check the invite. Check your connection."
        }
    }

    public var canJoin: Bool {
        guard let invite else { return false }
        return !invite.isExpired && !invite.isAccepted && isSignedIn && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public func join() async -> Bool {
        guard let invite, let account = authService.currentAccount, canJoin else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await setupService.acceptInvite(invite, account: account, name: name.trimmingCharacters(in: .whitespaces),
                                                existingOrgs: currentOrgs())
            return true
        } catch {
            errorMessage = "Couldn't join the shop. Try again."
            return false
        }
    }
}

public struct StaffJoinView: View {
    @Bindable private var viewModel: StaffJoinViewModel
    private let onSignIn: () -> Void
    private let onUseAnother: () -> Void

    public init(viewModel: StaffJoinViewModel, onSignIn: @escaping () -> Void, onUseAnother: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSignIn = onSignIn
        self.onUseAnother = onUseAnother
    }

    public var body: some View {
        ScreenScroll {
            if let invite = viewModel.invite {
                ManiHeroAmount(invite.role.title, caption: "at \(invite.storeName.isEmpty ? invite.orgName : invite.storeName) · invited by \(invite.invitedByName)", icon: .store)
                ManiKeyValueSummary(rows: [
                    ManiKeyValue("Name", invite.name),
                    ManiKeyValue("Phone", invite.phone),
                    ManiKeyValue("Access", invite.role == .cashier ? "Billing, returns, cash entries" : invite.role.title)
                ], emphasizeLast: false)
                ManiInputField(label: "Your name", text: $viewModel.name)
                if !viewModel.isSignedIn {
                    ManiNote("Sign in or create an account first, then come back to this invite.", kind: .info)
                }
            } else {
                ManiEmptyState(icon: .people, title: "Join your shop",
                               message: "Enter the invite code your owner sent you by SMS or WhatsApp.")
                ManiInputField(label: "Invite code", text: $viewModel.code, placeholder: "ABCD2345")
                ManiButton("Find invite", isLoading: viewModel.isWorking, isEnabled: viewModel.code.count >= 6) {
                    Task { await viewModel.load() }
                }
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            if viewModel.invite != nil {
                VStack(spacing: ManiSpacing.sm) {
                    if viewModel.isSignedIn {
                        ManiButton("Join shop", isLoading: viewModel.isWorking, isEnabled: viewModel.canJoin) {
                            Task { _ = await viewModel.join() }
                        }
                    } else {
                        ManiButton("Sign in to join", action: onSignIn)
                    }
                    ManiButton("Not you? Use another account", kind: .outline, action: onUseAnother)
                }
            }
        }
        .navigationTitle("You're invited")
        .task { await viewModel.load() }
    }
}

// MARK: - 06 PIN switch

@MainActor
@Observable
public final class PinSwitchViewModel {
    public private(set) var members: [Member] = []
    public var selected: Member?
    public var pin = ""
    public var errorMessage: String?

    private let session: AppSession
    private let memberRepository: any OrgCollectionRepositoryProtocol<Member>
    private let pinStore: PinStoring
    private let biometrics: BiometricAuthenticating

    public init(session: AppSession, memberRepository: any OrgCollectionRepositoryProtocol<Member>,
                pinStore: PinStoring, biometrics: BiometricAuthenticating) {
        self.session = session
        self.memberRepository = memberRepository
        self.pinStore = pinStore
        self.biometrics = biometrics
    }

    public var canUseBiometrics: Bool { biometrics.isAvailable && selected?.id == session.user?.id }

    public func load() async {
        members = ((try? await memberRepository.all()) ?? [])
            .filter { $0.isActive && $0.storeIds.contains(session.currentStoreId) || $0.role == .owner }
            .sorted { $0.name < $1.name }
        if members.isEmpty, let user = session.user {
            members = [Member(id: user.id, name: user.name, email: user.email, role: session.role)]
        }
    }

    public func hasPin(_ member: Member) -> Bool { pinStore.hasPin(for: member.id) }

    public func select(_ member: Member) {
        selected = member
        pin = ""
        errorMessage = nil
        // The signed-in account with no PIN set switches straight back.
        if member.id == session.user?.id && !pinStore.hasPin(for: member.id) {
            session.actAs(nil)
        }
    }

    /// Returns true when the PIN matched and the switch happened.
    public func keyPressed(_ key: ManiKeypadKey) -> Bool {
        pin = key.apply(to: pin, maxDecimals: 0, maxLength: 4)
        guard pin.count == 4, let member = selected else { return false }
        if pinStore.verify(pin, for: member.id) {
            session.actAs(member.id == session.user?.id ? nil : member)
            return true
        }
        errorMessage = "Wrong PIN. Try again."
        pin = ""
        return false
    }

    public func useBiometrics() async -> Bool {
        guard canUseBiometrics else { return false }
        let ok = await biometrics.authenticate(reason: "Switch back to your account")
        if ok { session.actAs(nil) }
        return ok
    }
}

public struct PinSwitchView: View {
    @Bindable private var viewModel: PinSwitchViewModel
    private let onSwitched: () -> Void

    public init(viewModel: PinSwitchViewModel, onSwitched: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSwitched = onSwitched
    }

    public var body: some View {
        ScreenScroll {
            SectionHeader(title: "Who's billing?")
            RowsCard {
                ForEach(viewModel.members) { member in
                    ManiListRow(avatar: ManiAvatar(initials: String(member.name.prefix(1))), title: member.name,
                                subtitle: member.role.title,
                                status: viewModel.selected?.id == member.id ? ("Selected", .success) : nil) {
                        viewModel.select(member)
                        if member.id == viewModel.selected?.id && !viewModel.hasPin(member) && member.role == .owner {
                            onSwitched()
                        }
                    }
                }
            }
            if let member = viewModel.selected {
                if viewModel.hasPin(member) {
                    ScreenSubtitle(text: "\(member.name), enter your PIN")
                    ManiCodeField(length: 4, code: viewModel.pin, secure: true)
                    ManiKeypad(showsDecimal: false) { key in
                        if viewModel.keyPressed(key) { onSwitched() }
                    }
                    if viewModel.canUseBiometrics {
                        ManiButton("Use Face ID / fingerprint", icon: .fingerprint, kind: .outline) {
                            Task { if await viewModel.useBiometrics() { onSwitched() } }
                        }
                    }
                } else {
                    ManiNote("\(member.name) hasn't set a PIN on this phone. The owner can set one in Admin → Staff.", kind: .info)
                }
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
            ScreenSubtitle(text: "Forgot your PIN? Ask the owner to reset it.")
        }
        .navigationTitle("Switch staff")
        .task { await viewModel.load() }
    }
}
