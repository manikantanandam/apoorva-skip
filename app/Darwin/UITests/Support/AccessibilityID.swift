//
//  AccessibilityID.swift
//  ApoorvaUITests
//
//  Keep raw values in sync with libraries/ApoorvaModules/.../Onboarding/AccessibilityID.swift.
//

enum AccessibilityID {
    enum Splash {
        static let getStarted = "splash.getStarted"
        static let demo = "splash.demo"
    }

    enum DemoShop {
        static let trySample = "demoShop.trySample"
    }

    enum SignInHub {
        static let emailButton = "signInHub.emailButton"
    }

    enum Customers {
        static let moreMenu = "customers.moreMenu"
    }

    enum Pos {
        static let customerRow = "pos.customerRow"
        static let billDate = "pos.billDate"
        static let holdBill = "pos.holdBill"
        static let heldBills = "pos.heldBills"
        static let moreMenu = "pos.moreMenu"
        static let find = "pos.find"
        static let checkout = "pos.checkout"
        static func tile(_ name: String) -> String { "pos.tile.\(name)" }
        static func cartLine(_ lineId: String) -> String { "pos.cartLine.\(lineId)" }
    }

    enum Checkout {
        static let customerRow = "checkout.customerRow"
        static let collect = "checkout.collect"
        static let hold = "checkout.hold"
        static let cashReceived = "checkout.cashReceived"
        static let changeDue = "checkout.changeDue"
        static let creditNote = "checkout.creditNote"
        static let error = "checkout.error"
        static func mode(_ name: String) -> String { "checkout.mode.\(name)" }
    }

    enum WeightSheet {
        static let price = "weightSheet.price"
        static let add = "weightSheet.add"
    }

    enum VariantSheet {
        static let quantity = "variantSheet.quantity"
        static let add = "variantSheet.add"
    }

    enum UPI {
        static let markReceived = "upi.markReceived"
        static let changeMode = "upi.changeMode"
    }

    enum SplitPayment {
        static let primary = "splitPayment.primary"
        static let creditNote = "splitPayment.creditNote"
        static let error = "splitPayment.error"
    }

    enum BillDiscount {
        static let apply = "billDiscount.apply"
        static let remove = "billDiscount.remove"
        static let managerPin = "billDiscount.managerPin"
        static func preset(_ percent: Int) -> String { "billDiscount.preset.\(percent)" }
    }

    enum Receipt {
        static let newBill = "receipt.newBill"
        static let home = "receipt.home"
        static let editBill = "receipt.editBill"
    }

    enum QuickAddLine {
        static let mrp = "quickAddLine.mrp"
        static let discount = "quickAddLine.discount"
        static let increase = "quickAddLine.increase"
        static let decrease = "quickAddLine.decrease"
        static let save = "quickAddLine.save"
        static let remove = "quickAddLine.remove"
    }

    enum CustomerPicker {
        static let addAndAttach = "customerPicker.addAndAttach"
        static let walkIn = "customerPicker.walkIn"
    }

    enum EmailSignIn {
        static let email = "emailSignIn.email"
        static let password = "emailSignIn.password"
        static let signInButton = "emailSignIn.signInButton"
        static let error = "emailSignIn.error"
    }
}

/// Credentials accepted by FakeAuthService (ApoorvaServices).
enum TestCredentials {
    static let email = "uitest@apoorva.app"
    static let password = "UITest@123"
}
