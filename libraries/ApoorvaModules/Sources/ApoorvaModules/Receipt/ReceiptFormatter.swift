//
//  ReceiptFormatter.swift
//  ApoorvaModules
//
//  Plain-text receipts: the WhatsApp/SMS share text and the 58 mm thermal layout (design 46).
//

import Foundation
import ApoorvaModels

public enum ReceiptFormatter {

    /// Text for WhatsApp / SMS / share sheet.
    public static func shareText(for sale: Sale, shopName: String? = nil, upiLink: String? = nil) -> String {
        var lines: [String] = []
        if let shopName, !shopName.isEmpty { lines.append("*\(shopName)*") }
        lines.append("\(sale.isReturn ? "Return" : "Bill") \(sale.displayNumber) · \(sale.timestamp.formatted(date: .abbreviated, time: .shortened))")
        for item in sale.items {
            lines.append("\(item.categoryName) × \(item.qty)  \(Money.format(item.totalAmount))")
        }
        if sale.overallDiscountAmount > 0 { lines.append("Discount: −\(Money.format(sale.overallDiscountAmount))") }
        lines.append("Total: \(Money.format(sale.netPayable))")
        if sale.isDue {
            lines.append("Balance due: \(Money.format(sale.dueAmount))")
            if let upiLink { lines.append("Pay by UPI: \(upiLink)") }
        }
        lines.append("Thank you! Visit again")
        return lines.joined(separator: "\n")
    }

    /// A 58 mm (32 column) or 80 mm (48 column) receipt. Tax lines only when tax is on.
    public static func thermalLines(for sale: Sale, settings: OrgSettings, shopName: String, columns: Int = 32) -> [String] {
        var out: [String] = []
        let rule = String(repeating: "-", count: columns)
        out.append(center(shopName.uppercased(), columns))
        let contact = [settings.profile.address, settings.profile.phone].filter { !$0.isEmpty }.joined(separator: " · ")
        if !contact.isEmpty { out.append(center(contact, columns)) }
        if !settings.receipt.header.isEmpty { out.append(center(settings.receipt.header, columns)) }
        if settings.tax.mode != .off, settings.tax.showOnReceipt, !settings.tax.gstin.isEmpty {
            out.append(center("GSTIN \(settings.tax.gstin)", columns))
        }
        out.append(rule)
        out.append(pair("\(sale.isReturn ? "Return" : "Bill") \(sale.displayNumber)",
                        sale.timestamp.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year().hour().minute()), columns))
        if !sale.customerName.isEmpty && sale.customerName != "Walk-in" { out.append(sale.customerName) }
        out.append(rule)
        for item in sale.items {
            let name = item.qty == 1 ? item.categoryName : "\(item.categoryName) x\(item.qty)"
            out.append(pair(name, String(format: "%.2f", item.totalAmount), columns))
            if let months = item.warrantyMonths, months > 0,
               let until = Calendar.current.date(byAdding: .month, value: months, to: sale.timestamp) {
                out.append("  Warranty till \(until.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))")
            }
        }
        out.append(rule)
        if sale.overallDiscountAmount > 0 { out.append(pair("Discount", String(format: "-%.2f", sale.overallDiscountAmount), columns)) }
        if settings.tax.mode != .off, settings.tax.showOnReceipt, settings.tax.ratePercent > 0 {
            let rate = settings.tax.ratePercent
            let tax = settings.tax.inclusive ? sale.netPayable * rate / (100 + rate) : sale.netPayable * rate / 100
            out.append(pair("CGST \(String(format: "%g", rate / 2))%", String(format: "%.2f", tax / 2), columns))
            out.append(pair("SGST \(String(format: "%g", rate / 2))%", String(format: "%.2f", tax / 2), columns))
        }
        if sale.roundOff != 0 { out.append(pair("Round off", String(format: "%.2f", -sale.roundOff), columns)) }
        out.append(pair("TOTAL", "Rs \(String(format: "%.2f", sale.netPayable))", columns))
        for (mode, amount) in sale.payments.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where amount != 0 {
            out.append(pair(mode.title, String(format: "%.2f", amount), columns))
        }
        out.append(rule)
        out.append(center(settings.receipt.footer.isEmpty ? "Thank you! Visit again" : settings.receipt.footer, columns))
        return out
    }

    static func pair(_ left: String, _ right: String, _ columns: Int) -> String {
        let space = columns - right.count - 1
        guard space > 0 else { return left + " " + right }
        let trimmed = left.count > space ? String(left.prefix(space)) : left
        return trimmed + String(repeating: " ", count: columns - trimmed.count - right.count) + right
    }

    static func center(_ text: String, _ columns: Int) -> String {
        guard text.count < columns else { return String(text.prefix(columns)) }
        return String(repeating: " ", count: (columns - text.count) / 2) + text
    }
}
