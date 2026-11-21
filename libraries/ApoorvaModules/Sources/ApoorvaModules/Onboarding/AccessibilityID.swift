//
//  AccessibilityID.swift
//  ApoorvaModules
//
//  Identifiers used by UI tests. Keep raw values in sync with app/Darwin/UITests/Support/AccessibilityID.swift.
//

import Foundation

public enum AccessibilityID {
    public enum Splash {
        public static let getStarted = "splash.getStarted"
    }

    public enum SignInHub {
        public static let emailButton = "signInHub.emailButton"
    }

    public enum Customers {
        public static let moreMenu = "customers.moreMenu"
    }

    public enum Pos {
        public static let customerRow = "pos.customerRow"
        public static let billDate = "pos.billDate"
        public static let holdBill = "pos.holdBill"
        public static let heldBills = "pos.heldBills"
        public static let moreMenu = "pos.moreMenu"
        public static let find = "pos.find"
        public static let checkout = "pos.checkout"
        public static func tile(_ name: String) -> String { "pos.tile.\(name)" }
        public static func cartLine(_ lineId: String) -> String { "pos.cartLine.\(lineId)" }
    }

    public enum Checkout {
        public static let customerRow = "checkout.customerRow"
        public static let collect = "checkout.collect"
        public static let hold = "checkout.hold"
        public static let cashReceived = "checkout.cashReceived"
        public static let changeDue = "checkout.changeDue"
        public static let creditNote = "checkout.creditNote"
        public static let error = "checkout.error"
        public static func mode(_ name: String) -> String { "checkout.mode.\(name)" }
    }

    public enum WeightSheet {
        public static let price = "weightSheet.price"
        public static let add = "weightSheet.add"
    }

    public enum VariantSheet {
        public static let quantity = "variantSheet.quantity"
        public static let add = "variantSheet.add"
    }

    public enum UPI {
        public static let markReceived = "upi.markReceived"
        public static let changeMode = "upi.changeMode"
    }

    public enum SplitPayment {
        public static let primary = "splitPayment.primary"
        public static let creditNote = "splitPayment.creditNote"
        public static let error = "splitPayment.error"
    }

    public enum BillDiscount {
        public static let apply = "billDiscount.apply"
        public static let remove = "billDiscount.remove"
        public static let managerPin = "billDiscount.managerPin"
        public static func preset(_ percent: Int) -> String { "billDiscount.preset.\(percent)" }
    }

    public enum Receipt {
        public static let newBill = "receipt.newBill"
        public static let home = "receipt.home"
        public static let editBill = "receipt.editBill"
        public static let undo = "receipt.undo"
    }

    public enum QuickAddLine {
        public static let mrp = "quickAddLine.mrp"
        public static let discount = "quickAddLine.discount"
        public static let increase = "quickAddLine.increase"
        public static let decrease = "quickAddLine.decrease"
        public static let save = "quickAddLine.save"
        public static let remove = "quickAddLine.remove"
    }

    public enum CustomerPicker {
        public static let addAndAttach = "customerPicker.addAndAttach"
        public static let walkIn = "customerPicker.walkIn"
    }

    public enum EmailSignIn {
        public static let email = "emailSignIn.email"
        public static let password = "emailSignIn.password"
        public static let signInButton = "emailSignIn.signInButton"
        public static let error = "emailSignIn.error"
    }
}
