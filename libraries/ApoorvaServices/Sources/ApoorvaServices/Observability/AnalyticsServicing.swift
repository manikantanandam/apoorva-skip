//
//  AnalyticsServicing.swift
//  ApoorvaServices
//

import Foundation

/// A single analytics parameter value. Kept as a closed, `Sendable` type (not `Any`) so the
/// abstraction below never leaks a concrete provider's SDK types to call sites.
public enum AnalyticsParameterValue: Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
}

/// A provider-neutral analytics event. Names/params follow docs/06 §2b's schema.
public struct AnalyticsEvent: Sendable {
    public let name: String
    public let parameters: [String: AnalyticsParameterValue]

    public init(name: String, parameters: [String: AnalyticsParameterValue] = [:]) {
        self.name = name
        self.parameters = parameters
    }
}

public extension AnalyticsEvent {
    static func signInMethod(_ method: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "sign_in_method", parameters: ["method": .string(method)])
    }

    static func billSaved(itemCount: Int, mode: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "bill_saved", parameters: ["item_count": .int(itemCount), "mode": .string(mode)])
    }

    static func trialStarted(days: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "trial_started", parameters: ["days": .int(days)])
    }

    /// Defined for schema completeness; no real purchase/upgrade flow exists yet to call it from.
    static func subscribed(plan: String, period: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "subscribed", parameters: ["plan": .string(plan), "period": .string(period)])
    }
}

// MARK: - Ecommerce (GA4 recommended names, so the built-in monetisation reports fill in)

public extension AnalyticsEvent {
    /// Every amount the app handles is in rupees.
    static let currency = "INR"

    private static func money(_ value: Double) -> [String: AnalyticsParameterValue] {
        ["value": .double(value), "currency": .string(currency)]
    }

    /// `source`: tap, scan, weight, variant, custom, calculator.
    static func addToCart(value: Double, quantity: Int, source: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "add_to_cart", parameters: money(value).merging(["quantity": .int(quantity), "source": .string(source)]) { $1 })
    }

    static func removeFromCart(value: Double, quantity: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "remove_from_cart", parameters: money(value).merging(["quantity": .int(quantity)]) { $1 })
    }

    static func beginCheckout(value: Double, itemCount: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "begin_checkout", parameters: money(value).merging(["item_count": .int(itemCount)]) { $1 })
    }

    /// `paymentType` is the joined payment modes, e.g. "Cash+UPI".
    static func purchase(transactionId: String, value: Double, discount: Double, itemCount: Int, paymentType: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase", parameters: money(value).merging([
            "transaction_id": .string(transactionId), "discount": .double(discount),
            "item_count": .int(itemCount), "payment_type": .string(paymentType)
        ]) { $1 })
    }

    /// A return bill carries its value; a cancelled bill is a full refund of `transactionId`, so it has none.
    static func refund(transactionId: String, value: Double?, reason: String) -> AnalyticsEvent {
        var parameters: [String: AnalyticsParameterValue] = ["transaction_id": .string(transactionId), "reason": .string(reason)]
        if let value { parameters.merge(money(value)) { $1 } }
        return AnalyticsEvent(name: "refund", parameters: parameters)
    }
}

// MARK: - Core usage and feature adoption (docs/06 §2b)

public extension AnalyticsEvent {
    static func billHeld(itemCount: Int, value: Double) -> AnalyticsEvent {
        AnalyticsEvent(name: "bill_held", parameters: money(value).merging(["item_count": .int(itemCount)]) { $1 })
    }

    static func scanUsed(matched: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "scan_used", parameters: ["matched": .bool(matched)])
    }

    /// `kind`: cashIn, cashOut, transfer.
    static func cashEntryAdded(kind: String, category: String, value: Double) -> AnalyticsEvent {
        AnalyticsEvent(name: "cash_entry_added", parameters: money(value).merging([
            "kind": .string(kind), "category": .string(category)
        ]) { $1 })
    }

    static func cashEntryEdited(category: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "cash_entry_edited", parameters: ["category": .string(category)])
    }

    static func cashEntryDeleted(category: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "cash_entry_deleted", parameters: ["category": .string(category)])
    }

    static func expenseAdded(category: String, value: Double, isNew: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "expense_added", parameters: money(value).merging([
            "category": .string(category), "is_new": .bool(isNew)
        ]) { $1 })
    }

    static func customerSaved(isNew: Bool, allowsCredit: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "customer_saved", parameters: ["is_new": .bool(isNew), "allows_credit": .bool(allowsCredit)])
    }

    static func dueCollected(value: Double, mode: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "due_collected", parameters: money(value).merging(["mode": .string(mode)]) { $1 })
    }

    static func itemSaved(isNew: Bool, hasVariants: Bool, hasBarcode: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "item_saved", parameters: [
            "is_new": .bool(isNew), "has_variants": .bool(hasVariants), "has_barcode": .bool(hasBarcode)
        ])
    }

    static func purchaseRecorded(value: Double, lineCount: Int, isReturn: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "purchase_recorded", parameters: money(value).merging([
            "line_count": .int(lineCount), "is_return": .bool(isReturn)
        ]) { $1 })
    }

    static func orderCreated(value: Double, advance: Double) -> AnalyticsEvent {
        AnalyticsEvent(name: "order_created", parameters: money(value).merging(["advance": .double(advance)]) { $1 })
    }

    static func openingBalancesSaved(customerCount: Int, supplierCount: Int, hasCash: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "opening_balances_saved", parameters: [
            "customer_count": .int(customerCount), "supplier_count": .int(supplierCount), "has_cash": .bool(hasCash)
        ])
    }
}

// MARK: - Reliability

public extension AnalyticsEvent {
    /// One event per full sync pass, never per collection.
    static func syncCompleted(durationMs: Int, collectionCount: Int, failedCount: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "sync_completed", parameters: [
            "duration_ms": .int(durationMs), "collection_count": .int(collectionCount), "failed_count": .int(failedCount)
        ])
    }

    /// `collection` is the sync key; `reason` is the error type name, never its message (which can carry data).
    static func syncFailed(collection: String, reason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "sync_failed", parameters: ["collection": .string(collection), "reason": .string(reason)])
    }

    /// `UsersMemberRepository.all()` resolved an org but `listUsers(orgId:)` came back empty — every org has
    /// at least an owner, so this means the org's `users` docs are missing the denormalized `assignedOrgIds`
    /// field the query filters on (pre-existing orgs from before that field was introduced never got it
    /// backfilled). `orgIdHash` avoids sending a raw org id to the analytics provider.
    static func orgMembersQueryEmpty(orgIdHash: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "org_members_query_empty", parameters: ["org_id_hash": .string(orgIdHash)])
    }
}

/// Provider-agnostic event tracking: swap the conformer, not the call sites.
public protocol AnalyticsServicing: Sendable {
    func log(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String?, forName name: String)
    func setUserId(_ id: String?)
    func setAnalyticsCollectionEnabled(_ enabled: Bool)
}

public extension AnalyticsServicing {
    func logScreenView(_ screenName: String) {
        log(AnalyticsEvent(name: "screen_view", parameters: ["screen_name": .string(screenName)]))
    }
}
