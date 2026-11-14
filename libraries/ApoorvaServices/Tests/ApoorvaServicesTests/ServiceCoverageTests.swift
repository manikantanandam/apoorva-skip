//
//  ServiceCoverageTests.swift
//  ApoorvaServices
//

import Testing
import Foundation
import FirebaseFirestore
import ApoorvaModels
@testable import ApoorvaServices

// MARK: - Helpers

private func collect<T>(_ stream: AsyncStream<T>) async -> [T] {
    var values: [T] = []
    for await value in stream { values.append(value) }
    return values
}

private func makeCustomer(phone: String = "9", name: String = "Asha") -> Customer {
    Customer(name: name, phone: phone, createdAt: 100, lastPurchaseDate: nil, totalSales: 0,
             totalAmountSpent: 0, updatedAt: nil, isDeleted: false)
}

private func makeSaleItem(full: Bool) -> SaleItem {
    SaleItem(categoryId: "c", categoryName: "Cat", qty: 1, stickerPrice: 10, finalPrice: 9, discountType: .amount,
             doneByStaffId: full ? "st" : nil, doneByName: full ? "Staff" : nil, warrantyMonths: full ? 6 : nil,
             weight: full ? 1.5 : nil, unit: full ? "kg" : nil, variant: full ? "red" : nil)
}

private func makeSale(full: Bool) -> Sale {
    var sale = Sale(id: "s1", staffId: "u", customerPhone: "9", customerName: "Asha", items: [makeSaleItem(full: full)],
                    subtotal: 10, overallDiscountPercent: 0, overallDiscountAmount: 0, roundOff: 0,
                    netPayable: 10, payments: [.cash: 10], timestamp: epoch(500), source: "POS",
                    status: "Completed", whatsappStatus: "unsent")
    if full {
        sale.storeId = "store"
        sale.billNumber = "B-1"
        sale.returnOfSaleId = "s0"
        sale.editReason = "typo"
        sale.editedAt = epoch(900)
    }
    return sale
}

private struct MinimalCustomerService: CustomerServiceProtocol {
    func getCustomers(for orgId: String) async throws -> [Customer] { [] }
    func getCustomers(since lastSync: Date, for orgId: String) async throws -> [Customer] { [] }
    func upsertCustomerAfterSale(phone: String, name: String, saleAmount: Double, saleDate: Date, for orgId: String) async throws {}
}

private struct MinimalInventoryService: InventoryItemServiceProtocol {
    func getInventoryItems(for orgId: String) async throws -> [InventoryItem] { [] }
    func getInventoryItems(since lastSync: Date, for orgId: String) async throws -> [InventoryItem] { [] }
}

/// Auth stub whose account stream stays open so tests can drive sign-in/out step by step.
private final class OpenAuthService: AuthServicing, @unchecked Sendable {
    let stream: AsyncStream<AuthAccount?>
    let continuation: AsyncStream<AuthAccount?>.Continuation

    init() {
        (stream, continuation) = AsyncStream.makeStream(of: AuthAccount?.self)
    }

    var currentUserStream: AsyncStream<AppUser?> { AsyncStream { $0.finish() } }
    var accountStream: AsyncStream<AuthAccount?> { stream }
    func login(email: String, password: String) async throws {}
    func logout() throws {}
}

@MainActor
private final class MinimalUserService: UserServiceProtocol {
    let userSessionStream: AsyncStream<AppUser?>
    var currentUser: AppUser? { nil }

    init(users: [AppUser?]) {
        userSessionStream = AsyncStream { continuation in
            users.forEach { continuation.yield($0) }
            continuation.finish()
        }
    }

    func updateSelectedOrganization(for user: AppUser, organization: OrganizationSnapshot) async throws {}
    func listUsers(orgId: String) async throws -> [AppUser] { [] }
    func updateRole(userId: String, role: AppUserRole) async throws {}
}

private struct FailingStore: FirestoreStoring {
    func getDocuments(collection path: String, query: StoreQuery) async throws -> [StoreDocument] { throw AuthServiceError.unsupported }
    func getDocument(path: String) async throws -> StoreDocument? { throw AuthServiceError.unsupported }
    func setData(_ data: [String: Any], path: String, merge: Bool) throws {}
    func updateData(_ fields: [String: Any], path: String) async throws {}
}

// MARK: - Store seam

private struct StrictRecord: Decodable {
    let id: String
    let name: String
}

struct FirestoreStoringTests {
    @Test func storeQueryDefaultsAndAll() {
        #expect(StoreQuery.all.conditions.isEmpty)
        #expect(!StoreQuery.all.matchAny)
    }

    @Test func storeDocumentKeepsIdAndData() {
        let document = StoreDocument(id: "d", data: ["a": 1])
        #expect(document.id == "d")
        #expect(document.data["a"] as? Int == 1)
    }

    @Test func defaultListenYieldsDocumentThenFinishes() async throws {
        let store = MockFirestoreStore()
        store.documents["x/1"] = ["a": 1]
        let values = await collect(store.listen(path: "x/1"))
        #expect(values.count == 1)
        #expect(values[0]?.id == "1")
    }

    @Test func defaultListenYieldsNilWhenMissingOrFailing() async {
        let missing = await collect(MockFirestoreStore().listen(path: "x/none"))
        let failing = await collect(FailingStore().listen(path: "x/1"))
        #expect(missing.count == 1 && missing[0] == nil)
        #expect(failing.count == 1 && failing[0] == nil)
    }

    @Test func setEncodesValueIntoStore() throws {
        let store = MockFirestoreStore()
        try store.set(makeInventoryItem("i1"), path: "inv/i1")
        #expect(store.writes.first?.path == "inv/i1")
        #expect(store.writes.first?.merge == false)
        try store.set(makeInventoryItem("i1"), path: "inv/i1", merge: true)
        #expect(store.writes.last?.merge == true)
    }

    @Test func fetchSkipsUndecodableAndFillsMissingId() async throws {
        let store = MockFirestoreStore()
        store.documents["c/legacy"] = ["name": "L"]
        store.documents["c/bad"] = ["id": "bad"]
        let items = try await store.fetch(StrictRecord.self, collection: "c")
        #expect(items.map(\.id) == ["legacy"])
    }

    @Test func sentinelIsStable() {
        #expect(StoreSentinel.serverTimestamp == "__apoorva_server_timestamp__")
    }
}

struct FirestorePayloadHelperTests {
    @Test func ensureIdFieldMutatesPayload() {
        var payload: [String: Any] = ["a": 1]
        let result = FirestorePayloadHelper.ensureIdField(in: &payload, id: "x")
        #expect(payload["id"] as? String == "x")
        #expect(result["id"] as? String == "x")
    }

    @Test func payloadWithIdDoesNotMutateInput() {
        let input: [String: Any] = ["a": 1]
        let output = FirestorePayloadHelper.payloadWithId(input, id: "x")
        #expect(input["id"] == nil)
        #expect(output["id"] as? String == "x")
    }
}

// MARK: - Entity services

struct HeldBillServiceTests {
    private func bill(_ id: String) -> HeldBill {
        HeldBill(id: id, customerName: "A", customerPhone: "9", items: [], total: 5)
    }

    @Test func addWritesWithoutMerge() async throws {
        let store = MockFirestoreStore()
        try await HeldBillService(store: store).addHeldBill(bill("h1"), for: "o")
        #expect(store.writes.first?.path == "organizations/o/heldBills/h1")
        #expect(store.writes.first?.merge == false)
    }

    @Test func updateMergesAndStampsUpdatedAt() async throws {
        let store = MockFirestoreStore()
        try await HeldBillService(store: store).updateHeldBill(bill("h1"), for: "o")
        #expect(store.writes.first?.merge == true)
        #expect(store.writes.first?.data["updatedAt"] != nil)
    }

    @Test func deleteSoftDeletes() async throws {
        let store = MockFirestoreStore()
        try await HeldBillService(store: store).deleteHeldBill(id: "h1", for: "o")
        #expect(store.updates.first?.path == "organizations/o/heldBills/h1")
        #expect(store.updates.first?.fields["isDeleted"] as? Bool == true)
    }

    @Test func fetchesAllAndDelta() async throws {
        let store = MockFirestoreStore()
        let service = HeldBillService(store: store)
        var old = bill("old"); old.updatedAt = epoch(10)
        var new = bill("new"); new.updatedAt = epoch(500)
        try store.put(old, at: "organizations/o/heldBills/old")
        try store.put(new, at: "organizations/o/heldBills/new")
        #expect(try await service.getHeldBills(for: "o").count == 2)
        #expect(try await service.getHeldBills(since: epoch(100), for: "o").map(\.id) == ["new"])
    }
}

struct PlatformConfigServiceTests {
    @Test func fetchReturnsDefaultsWhenMissing() async throws {
        let config = try await PlatformConfigService(store: MockFirestoreStore()).fetch()
        #expect(config == PlatformConfig())
    }

    @Test func saveThenFetchRoundTripsAndStampsUpdatedAt() async throws {
        let store = MockFirestoreStore()
        let service = PlatformConfigService(store: store)
        try service.save(PlatformConfig(minAppVersion: "3.0.0"))
        #expect(store.writes.first?.path == PlatformConfigService.path)
        #expect(store.writes.first?.merge == true)
        let fetched = try await service.fetch()
        #expect(fetched.minAppVersion == "3.0.0")
        #expect(fetched.updatedAt != nil)
    }

    @Test func undecodableDocumentFallsBackToDefaults() {
        let config = PlatformConfigService.decode(StoreDocument(id: "config", data: ["flags": "bad"]))
        #expect(config == PlatformConfig())
    }

    @Test func listenYieldsDecodedConfig() async throws {
        let store = MockFirestoreStore()
        store.documents[PlatformConfigService.path] = try Firestore.Encoder().encode(PlatformConfig(minAppVersion: "4.0.0"))
        let values = await collect(PlatformConfigService(store: store).listen())
        #expect(values.first?.minAppVersion == "4.0.0")
    }
}

struct DailyCashflowSummaryFailureTests {
    @Test func undecodableSummaryThrows() async {
        let store = MockFirestoreStore()
        store.documents["organizations/o/dailyCashflowSummaries/bad"] = ["date": "not a date"]
        await #expect(throws: (any Error).self) {
            try await DailyCashflowSummaryService(store: store).getDailyCashflowSummary(orgId: "o", date: "bad")
        }
    }

    @Test func deltaFetchRethrowsStoreFailure() async {
        await #expect(throws: AuthServiceError.self) {
            try await DailyCashflowSummaryService(store: FailingStore()).getDailyCashflowSummaries(since: epoch(0), for: "o")
        }
    }
}

struct ListenTerminationTests {
    @Test func breakingOutOfDefaultListenCancelsTheTask() async {
        let store = MockFirestoreStore()
        store.documents["x/1"] = ["a": 1]
        for await _ in store.listen(path: "x/1") { break }
    }

    @Test func breakingOutOfPlatformConfigListenCancelsTheTask() async {
        for await _ in PlatformConfigService(store: MockFirestoreStore()).listen() { break }
    }
}

struct CustomerServiceWriteTests {
    @Test func upsertCustomerSkipsEmptyPhone() throws {
        let store = MockFirestoreStore()
        try CustomerService(store: store).upsertCustomer(makeCustomer(phone: ""), for: "o")
        #expect(store.writes.isEmpty)
    }

    @Test func upsertCustomerWritesRequiredAndOptionalFields() throws {
        let store = MockFirestoreStore()
        var customer = makeCustomer()
        customer.creditLimit = 500
        customer.birthday = 1_000
        customer.priceTier = "wholesale"
        customer.notes = "vip"
        try CustomerService(store: store).upsertCustomer(customer, for: "o")
        let write = try #require(store.writes.first)
        #expect(write.path == "organizations/o/customers/9")
        #expect(write.merge)
        for key in ["creditLimit", "birthday", "priceTier", "notes"] { #expect(write.data[key] != nil) }
    }

    @Test func upsertCustomerOmitsAbsentOptionals() throws {
        let store = MockFirestoreStore()
        try CustomerService(store: store).upsertCustomer(makeCustomer(), for: "o")
        #expect(store.writes.first?.data["creditLimit"] == nil)
    }

    @Test func afterSaleSkipsEmptyPhone() async throws {
        let store = MockFirestoreStore()
        try await CustomerService(store: store).upsertCustomerAfterSale(phone: "", name: "A", saleAmount: 1, saleDate: Date(), for: "o")
        #expect(store.writes.isEmpty && store.updates.isEmpty)
    }

    @Test func afterSaleCreatesCustomerOnFirstSale() async throws {
        let store = MockFirestoreStore()
        try await CustomerService(store: store).upsertCustomerAfterSale(phone: "9", name: "A", saleAmount: 40, saleDate: epoch(5), for: "o")
        let write = try #require(store.writes.first)
        #expect(write.merge == false)
        #expect(write.data["totalSales"] as? Int == 1)
        #expect(write.data["totalAmountSpent"] as? Double == 40)
    }

    @Test func afterSaleBumpsExistingStats() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/o/customers/9"] = ["totalSales": 2, "totalAmountSpent": 10.0]
        try await CustomerService(store: store).upsertCustomerAfterSale(phone: "9", name: "A", saleAmount: 5, saleDate: epoch(5), for: "o")
        let update = try #require(store.updates.first)
        #expect(update.fields["totalSales"] as? Int == 3)
        #expect(update.fields["totalAmountSpent"] as? Double == 15)
    }

    @Test func afterSaleTreatsMissingStatsAsZero() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/o/customers/9"] = ["name": "A"]
        try await CustomerService(store: store).upsertCustomerAfterSale(phone: "9", name: "A", saleAmount: 5, saleDate: epoch(5), for: "o")
        #expect(store.updates.first?.fields["totalSales"] as? Int == 1)
        #expect(store.updates.first?.fields["totalAmountSpent"] as? Double == 5)
    }

    @Test func protocolDefaultUpsertIsNoOp() throws {
        try MinimalCustomerService().upsertCustomer(makeCustomer(), for: "o")
    }
}

struct InventoryItemWriteTests {
    @Test func upsertWritesRequiredFieldsOnly() throws {
        let store = MockFirestoreStore()
        try InventoryItemService(store: store).upsertInventoryItem(makeInventoryItem("i1"), for: "o")
        let write = try #require(store.writes.first)
        #expect(write.path == "organizations/o/inventory/i1")
        #expect(write.merge)
        #expect(write.data["barcode"] == nil)
        #expect(write.data["serverUpdatedAt"] as? String == StoreSentinel.serverTimestamp)
    }

    @Test func upsertWritesEveryOptionalField() throws {
        let store = MockFirestoreStore()
        var item = makeInventoryItem("i1", lastSold: 5)
        item.barcode = "b"; item.sellPrice = 1; item.costPrice = 1; item.wholesalePrice = 1
        item.categoryId = "c"; item.unit = "kg"; item.lowStockThreshold = 2; item.imageURLs = ["u"]
        item.designCode = "d"; item.variantsJSON = "[]"; item.warrantyMonths = 3
        try InventoryItemService(store: store).upsertInventoryItem(item, for: "o")
        let data = try #require(store.writes.first?.data)
        for key in ["lastSoldDate", "barcode", "sellPrice", "costPrice", "wholesalePrice", "categoryId", "unit",
                    "lowStockThreshold", "imageURLs", "designCode", "variantsJSON", "warrantyMonths"] {
            #expect(data[key] != nil, "missing \(key)")
        }
    }

    @Test func protocolDefaultUpsertIsNoOp() throws {
        try MinimalInventoryService().upsertInventoryItem(makeInventoryItem("i"), for: "o")
    }
}

struct SaleServiceCoverageTests {
    @Test func addSaleWritesOptionalFieldsWhenPresent() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).addSale(makeSale(full: true), for: "o")
        let data = try #require(store.writes.first?.data)
        #expect(data["storeId"] as? String == "store")
        #expect(data["billNumber"] as? String == "B-1")
        #expect(data["returnOfSaleId"] as? String == "s0")
        let line = (data["items"] as? [[String: Any]])?.first
        for key in ["doneByStaffId", "doneByName", "warrantyMonths", "weight", "unit", "variant"] {
            #expect(line?[key] != nil, "missing \(key)")
        }
    }

    @Test func addSaleOmitsAbsentOptionalFields() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).addSale(makeSale(full: false), for: "o")
        let data = try #require(store.writes.first?.data)
        #expect(data["storeId"] == nil && data["billNumber"] == nil && data["returnOfSaleId"] == nil)
        #expect((data["items"] as? [[String: Any]])?.first?["unit"] == nil)
    }

    @Test func updateSaleUsesEditFields() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).updateSale(makeSale(full: true), for: "o")
        let update = try #require(store.updates.first)
        #expect(update.path == "organizations/o/sales/s1")
        #expect(update.fields["editReason"] as? String == "typo")
        #expect(update.fields["serverUpdatedAt"] as? String == StoreSentinel.serverTimestamp)
    }

    @Test func updateSaleDefaultsMissingEditInfo() async throws {
        let store = MockFirestoreStore()
        try await SaleService(store: store).updateSale(makeSale(full: false), for: "o")
        #expect(store.updates.first?.fields["editReason"] as? String == "")
        #expect(store.updates.first?.fields["editedAt"] != nil)
    }
}

// MARK: - OrgCollection / OrganizationSetup / UserService

struct OrgCollectionCoverageTests {
    @Test func fetchSkipsUndecodableDocuments() async throws {
        let store = MockFirestoreStore()
        store.documents["organizations/org/customerLedger/bad"] = ["amount": "nope"]
        let result = try await OrgCollectionService<CustomerLedgerEntry>(store: store).fetch(since: nil, orgId: "org")
        #expect(result.documents.isEmpty)
        #expect(result.latestServerUpdate == nil)
    }

    @Test func fetchAcceptsPlainDateServerTimestamp() async throws {
        let store = MockFirestoreStore()
        var data = try Firestore.Encoder().encode(
            CustomerLedgerEntry(id: "a", customerPhone: "9", customerName: "A", kind: .payment, amount: 1, createdBy: "u"))
        data["serverUpdatedAt"] = epoch(300)
        store.documents["organizations/org/customerLedger/a"] = data
        let result = try await OrgCollectionService<CustomerLedgerEntry>(store: store).fetch(since: nil, orgId: "org")
        #expect(result.latestServerUpdate == epoch(300))
    }

    @Test func fetchResultHoldsValues() {
        let result = OrgFetchResult<CustomerLedgerEntry>(documents: [], latestServerUpdate: epoch(1))
        #expect(result.latestServerUpdate == epoch(1))
    }
}

struct OrganizationSetupCoverageTests {
    private let account = AuthAccount(uid: "u1", email: nil, isEmailVerified: true)

    private func invite(role: OrgRole) -> Invite {
        Invite(token: "ABCD2345", orgId: "org1", orgName: "Glitz", storeIds: [], storeName: "", role: role,
               name: "A", phone: "9", invitedBy: "u0", invitedByName: "K")
    }

    @Test func createInviteAndFetchInviteRoundTrip() async throws {
        let store = MockFirestoreStore()
        let service = OrganizationSetupService(store: store)
        try service.createInvite(invite(role: .cashier))
        #expect(store.writes.first?.path == "invites/ABCD2345")
        #expect(try await service.fetchInvite(token: "abcd2345")?.orgId == "org1")
        #expect(try await service.fetchInvite(token: "missing") == nil)
    }

    @Test func acceptInviteMapsEveryRole() async throws {
        let expected: [(OrgRole, AppUserRole)] = [(.owner, .admin), (.manager, .manager), (.cashier, .standard), (.accountant, .standard)]
        for (role, legacy) in expected {
            let store = MockFirestoreStore()
            try await OrganizationSetupService(store: store)
                .acceptInvite(invite(role: role), account: account, name: "A", existingOrgs: [try makeOrgSnapshot("org1"), try makeOrgSnapshot("other")])
            #expect(store.documents["users/u1"]?["role"] as? String == legacy.rawValue)
            #expect((store.documents["users/u1"]?["assignedOrgIds"] as? [String])?.count == 2)
        }
    }

    @Test func updateOrganizationStatusWritesReason() async throws {
        let store = MockFirestoreStore()
        try await OrganizationSetupService(store: store).updateOrganizationStatus(orgId: "o", status: "Suspended", reason: "dues")
        #expect(store.updates.first?.path == "organizations/o")
        #expect(store.updates.first?.fields["statusReason"] as? String == "dues")
    }

    @Test func fetchAllOrganizationsDecodesDocs() async throws {
        let store = MockFirestoreStore()
        try store.put(makeOrganization("a"), at: "organizations/a")
        #expect(try await OrganizationSetupService(store: store).fetchAllOrganizations().map(\.id) == ["a"])
    }

    @Test func createShopWorksWithoutOwnerEmail() async throws {
        let store = MockFirestoreStore()
        let shop = NewShop(ownerName: "K", shopName: "S", phone: "9", address: "A", billPrefix: "S-", vertical: .fancy,
                           theme: OrgSettings.Theme(accent: .plum, style: .bold), trialDays: 14)
        _ = try await OrganizationSetupService(store: store).createShop(shop, owner: account)
        #expect(store.documents["users/u1"]?["email"] as? String == "")
    }
}

@MainActor
struct UserServiceCoverageTests {
    @Test func sessionStreamEmitsProfileThenSignOut() async throws {
        let auth = OpenAuthService()
        let store = MockFirestoreStore()
        store.documents["users/u1"] = ["name": "Full", "email": "u@u.com"]
        let service = UserService(authService: auth, store: store)
        var iterator = service.sessionStream.makeAsyncIterator()

        let account = AuthAccount(uid: "u1", email: "u@u.com", isEmailVerified: true)
        auth.continuation.yield(account)
        let signedIn = await iterator.next()
        #expect(signedIn?.account == account)
        #expect(signedIn?.profile?.id == "u1")
        #expect(service.currentUser?.name == "Full")

        auth.continuation.yield(nil)
        let signedOut = await iterator.next()
        #expect(signedOut?.account == nil && signedOut?.profile == nil)
        #expect(service.currentUser == nil)
    }

    @Test func sessionStreamYieldsNilProfileWhenDocMissing() async {
        let auth = OpenAuthService()
        let service = UserService(authService: auth, store: MockFirestoreStore())
        var iterator = service.sessionStream.makeAsyncIterator()
        auth.continuation.yield(AuthAccount(uid: "ghost", email: nil, isEmailVerified: false))
        let snapshot = await iterator.next()
        #expect(snapshot?.account?.uid == "ghost")
        #expect(snapshot?.profile == nil)
        auth.continuation.finish()
    }

    @Test func createProfileWithoutOrganization() async throws {
        let store = MockFirestoreStore()
        let service = UserService(authService: StubAuthService(users: []), store: store)
        try await service.createProfile(for: AuthAccount(uid: "u1", email: nil, isEmailVerified: true), name: "N", role: .admin, organization: nil)
        let data = try #require(store.documents["users/u1"])
        #expect(data["email"] as? String == "")
        #expect(data["selectedOrganization"] == nil)
    }

    @Test func createProfileWithOrganization() async throws {
        let store = MockFirestoreStore()
        let service = UserService(authService: StubAuthService(users: []), store: store)
        try await service.createProfile(for: AuthAccount(uid: "u1", email: "e@e.com", isEmailVerified: true), name: "N", role: .admin,
                                        organization: try makeOrgSnapshot("o1"))
        let data = try #require(store.documents["users/u1"])
        #expect(data["assignedOrgIds"] as? [String] == ["o1"])
        #expect(data["selectedOrganization"] != nil)
    }

    @Test func setAssignedOrganizationsWritesIdsAndSelection() async throws {
        let store = MockFirestoreStore()
        let service = UserService(authService: StubAuthService(users: []), store: store)
        let orgs = [try makeOrgSnapshot("a"), try makeOrgSnapshot("b")]
        try await service.setAssignedOrganizations(userId: "u1", organizations: orgs, selected: orgs[1])
        #expect(store.documents["users/u1"]?["assignedOrgIds"] as? [String] == ["a", "b"])
    }

    @Test func updateRoleRethrowsStoreFailure() async {
        struct ThrowingStore: FirestoreStoring {
            func getDocuments(collection path: String, query: StoreQuery) async throws -> [StoreDocument] { [] }
            func getDocument(path: String) async throws -> StoreDocument? { nil }
            func setData(_ data: [String: Any], path: String, merge: Bool) throws {}
            func updateData(_ fields: [String: Any], path: String) async throws { throw AuthServiceError.unsupported }
        }
        let service = UserService(authService: StubAuthService(users: []), store: ThrowingStore())
        await #expect(throws: AuthServiceError.self) { try await service.updateRole(userId: "u", role: .admin) }
        await #expect(throws: AuthServiceError.self) {
            try await service.updateSelectedOrganization(for: try makeAppUser("u"), organization: try makeOrgSnapshot("o"))
        }
    }

    @Test func authErrorDescriptions() {
        #expect(UserService.AuthError.noUserLoggedIn.errorDescription != nil)
        #expect(UserService.AuthError.userDocumentNotFound.errorDescription != nil)
    }

    @Test func protocolDefaultsDeriveSessionFromUserStream() async throws {
        let service = MinimalUserService(users: [try makeAppUser("u1"), nil])
        let snapshots = await collect(service.sessionStream)
        #expect(snapshots.count == 2)
        #expect(snapshots[0].account?.uid == "u1")
        #expect(snapshots[1].account == nil)
        try await service.createProfile(for: AuthAccount(uid: "u", email: nil, isEmailVerified: true), name: "n", role: .admin, organization: nil)
        try await service.setAssignedOrganizations(userId: "u", organizations: [], selected: try makeOrgSnapshot("o"))
    }

    @Test func sessionSnapshotEquality() throws {
        let account = AuthAccount(uid: "u1", email: nil, isEmailVerified: true)
        let user = try makeAppUser("u1")
        let a = SessionSnapshot(account: account, profile: user)
        #expect(a == SessionSnapshot(account: account, profile: user))
        #expect(a != SessionSnapshot(account: account, profile: try makeAppUser("u2")))
        #expect(a != SessionSnapshot(account: account, profile: nil))
        #expect(a != SessionSnapshot(account: nil, profile: try makeAppUser("u1")))
    }
}

// MARK: - Auth protocol defaults

struct AuthServicingDefaultsTests {
    @Test func defaultsReportUnsupported() async {
        let auth = StubAuthService(users: [])
        #expect(auth.currentAccount == nil)
        #expect(auth.linkedProviders() == ["password"])
        await #expect(throws: AuthServiceError.self) { try await auth.register(name: "n", email: "e", password: "p") }
        await #expect(throws: AuthServiceError.self) { try await auth.sendEmailVerification() }
        await #expect(throws: AuthServiceError.self) { try await auth.sendPasswordReset(email: "e") }
        await #expect(throws: AuthServiceError.self) { try await auth.linkEmail(email: "e", password: "p") }
        await #expect(throws: AuthServiceError.self) { try await auth.updatePassword("p") }
        let reloaded = try? await auth.reloadAccount()
        #expect(reloaded == nil)
    }

    @Test func accountStreamMapsUsers() async throws {
        let accounts = await collect(StubAuthService(users: [try makeAppUser("u1"), nil]).accountStream)
        #expect(accounts.count == 2)
        #expect(accounts[0]?.uid == "u1")
        #expect(accounts[1] == nil)
    }

    @Test func errorDescriptions() {
        #expect(AuthServiceError.notSignedIn.errorDescription != nil)
        #expect(AuthServiceError.unsupported.errorDescription != nil)
        #expect(AuthServiceError.accountExistsWithDifferentCredential(email: "e").errorDescription != nil)
        #expect(AuthServiceError.message("boom").errorDescription == "boom")
    }
}

// MARK: - Observability

struct ObservabilityTests {
    @Test func analyticsEventFactories() {
        #expect(AnalyticsEvent.signInMethod("google").name == "sign_in_method")
        #expect(AnalyticsEvent.billSaved(itemCount: 2, mode: "POS").parameters.count == 2)
        #expect(AnalyticsEvent.trialStarted(days: 30).name == "trial_started")
        #expect(AnalyticsEvent.subscribed(plan: "pro", period: "monthly").name == "subscribed")
        #expect(AnalyticsEvent(name: "x").parameters.isEmpty)
    }

    @Test func noOpAnalyticsAcceptsEverything() {
        let service = NoOpAnalyticsService()
        service.log(AnalyticsEvent(name: "x"))
        service.logScreenView("Home")
        service.setUserProperty("v", forName: "n")
        service.setUserId(nil)
        service.setAnalyticsCollectionEnabled(false)
    }

    @Test func noOpCrashReportingAcceptsEverything() {
        let service = NoOpCrashReportingService()
        service.recordNonFatal(AuthServiceError.unsupported, context: "c")
        service.setCustomKey("v", forKey: "k")
        service.setUserId("u")
        service.log("m")
        service.setShopId("shop")
        service.setLaunchContext(appVersion: "1", buildFlavor: "debug")
        service.leaveBreadcrumb(screen: "S", action: "A")
    }

    @Test func stableHashIsDeterministicAndHandlesEmpty() {
        #expect(NoOpCrashReportingService.stableHash(nil) == "none")
        #expect(NoOpCrashReportingService.stableHash("") == "none")
        #expect(NoOpCrashReportingService.stableHash("shop") == NoOpCrashReportingService.stableHash("shop"))
        #expect(NoOpCrashReportingService.stableHash("a") != NoOpCrashReportingService.stableHash("b"))
    }

    @Test func noOpPerformanceRunsOperationAndRethrows() async throws {
        let service = NoOpPerformanceMonitoringService()
        #expect(await service.measure("t") { 42 } == 42)
        await #expect(throws: AuthServiceError.self) {
            try await service.measure("t") { throw AuthServiceError.unsupported }
        }
    }
}

// MARK: - Remote config

struct RemoteConfigCoverageTests {
    @Test func noOpReturnsDefaultsByType() async throws {
        let service = NoOpRemoteConfigService()
        try await service.fetchAndActivate()
        #expect(!service.boolValue(forKey: "b"))
        #expect(service.stringValue(forKey: "s") == nil)
        #expect(service.numberValue(forKey: "n") == nil)

        service.setDefaults(["b": .bool(true), "s": .string("x"), "n": .number(2), "j": .string("not json")])
        #expect(service.boolValue(forKey: "b"))
        #expect(service.stringValue(forKey: "s") == "x")
        #expect(service.numberValue(forKey: "n") == 2)
        #expect(service.jsonValue(forKey: "j", as: VersionGateValue.self) == nil)
        // Wrong-typed lookups fall through to the zero value.
        #expect(!service.boolValue(forKey: "s"))
        #expect(service.stringValue(forKey: "b") == nil)
        #expect(service.numberValue(forKey: "s") == nil)
    }

    @Test func markRemoteControlsIsRemoteValue() {
        let service = NoOpRemoteConfigService()
        #expect(!service.isRemoteValue(forKey: "k"))
        service.markRemote(["k"])
        #expect(service.isRemoteValue(forKey: "k"))
    }

    @Test func appConfigFetchDelegates() async throws {
        try await AppConfig(service: NoOpRemoteConfigService()).fetchAndActivate()
    }

    @Test func catalogDefaultsCoverEveryKind() {
        let defaults = RemoteConfigCatalogDefaults.make()
        #expect(defaults.count == RemoteConfigCatalog.all.count)
        for definition in RemoteConfigCatalog.all {
            let value = defaults[definition.key]
            switch (definition.kind, value) {
            case (.bool, .bool?), (.string, .string?), (.number, .number?), (.versionGate, .json?): break
            default: Issue.record("unexpected default type for \(definition.key)")
            }
        }
    }
}

// MARK: - Collection names

struct FirebaseCollectionNameTests {
    @Test func orgPathJoinsOrgAndCollection() {
        #expect(String.orgPath("o", .sales) == "organizations/o/sales")
        #expect(String.users == "users")
        #expect(String.organizations == "organizations")
    }
}

// MARK: - PIN store

struct PinStoreTests {
    @Test func inMemoryStoreSetVerifyRemove() throws {
        let store = InMemoryPinStore()
        #expect(!store.hasPin(for: "m"))
        try store.setPin("1234", for: "m")
        #expect(store.hasPin(for: "m"))
        #expect(store.verify("1234", for: "m"))
        #expect(!store.verify("0000", for: "m"))
        try store.removePin(for: "m")
        #expect(!store.hasPin(for: "m"))
    }

    @Test func hashDependsOnSaltAndPin() {
        #expect(KeychainPinStore.hash("1234", salt: "a") == KeychainPinStore.hash("1234", salt: "a"))
        #expect(KeychainPinStore.hash("1234", salt: "a") != KeychainPinStore.hash("1234", salt: "b"))
        #expect(KeychainPinStore.hash("1234", salt: "a") != KeychainPinStore.hash("4321", salt: "a"))
    }

    @Test func keychainStoreRoundTripsWhenKeychainIsAvailable() {
        let store = KeychainPinStore()
        let member = "test-\(UUID().uuidString)"
        #expect(!store.hasPin(for: member))
        #expect(!store.verify("1234", for: member))
        // The simulator test host may deny keychain writes; only assert when the write succeeds.
        if (try? store.setPin("1234", for: member)) != nil {
            #expect(store.hasPin(for: member))
            #expect(store.verify("1234", for: member))
            #expect(!store.verify("9999", for: member))
        }
        try? store.removePin(for: member)
        #expect(!store.hasPin(for: member))
    }

    @Test func deviceBiometricsReportsAvailabilityWithoutCrashing() async {
        let biometrics = DeviceBiometrics()
        let available = biometrics.isAvailable
        if !available { #expect(await biometrics.authenticate(reason: "test") == false) }
    }
}
