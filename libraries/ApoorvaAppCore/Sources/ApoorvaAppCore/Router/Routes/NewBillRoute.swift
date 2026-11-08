import Foundation

enum NewBillRoute: Hashable, Identifiable {
    case verticalPicker
    case customerPicker
    case lineEdit(itemId: String)
    case discount
    case checkout
    case split
    case upiQR
    case receipt(saleId: String)
    case held
    case returnExchange(billId: String)
    case scan

    var id: Self { self }
}
