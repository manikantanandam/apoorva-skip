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
    case receiptPreview(saleId: String)
    case held
    case returnExchange(billId: String)
    case scan
    case jewelItem(itemId: String)
    case catalogShare
    case parlourPackages

    var id: Self { self }
}

/// Bottom sheets over the POS screen (designs 27, 28, 32, 34, 41).
enum NewBillSheet: Hashable, Identifiable {
    case weight(itemId: String)
    case customItem
    case variant(itemId: String)
    case discount
    case priceTier

    var id: Self { self }
}
