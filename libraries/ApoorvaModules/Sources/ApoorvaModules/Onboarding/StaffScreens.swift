//
//  StaffScreens.swift
//  ApoorvaModules
//
//  Design 06 (PIN switch on shared phones).
//

import SwiftUI
import Observation
import ManiSwiftUIComponents
import ApoorvaModels
import ApoorvaServices
import ApoorvaRepository

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
