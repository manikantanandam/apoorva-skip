//
//  POSSheets.swift
//  ApoorvaModules
//
//  Bottom sheets over the POS: weight (27), quick item (28), variant (32), line edit (33),
//  bill discount (34).
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents

// MARK: - Weight (27)

/// Loose item entry by weight or by amount.
public struct WeightEntry: Equatable, Sendable {
    public enum Mode: String, CaseIterable, Sendable { case weight = "By weight", amount = "By amount" }

    public var mode: Mode = .weight
    public var text: String = "0.5"
    public let pricePerUnit: Double

    public init(pricePerUnit: Double) {
        self.pricePerUnit = pricePerUnit
    }

    public var weight: Double {
        let value = Double(text) ?? 0
        guard mode == .amount else { return value }
        return pricePerUnit > 0 ? (value / pricePerUnit * 1000).rounded() / 1000 : 0
    }

    public var amount: Double {
        mode == .amount ? (Double(text) ?? 0) : (weight * pricePerUnit).rounded()
    }

    public mutating func preset(grams: Int) {
        mode = .weight
        text = String(format: "%g", Double(grams) / 1000)
    }
}

public struct WeightSheet: View {
    @Environment(\.maniTheme) private var theme
    private let item: InventoryItem
    private let onAdd: (_ weight: Double, _ pricePerUnit: Double) -> Void
    @State private var entry: WeightEntry
    @State private var priceText: String

    public init(item: InventoryItem, pricePerUnit: Double?, onAdd: @escaping (Double, Double) -> Void) {
        self.item = item
        self.onAdd = onAdd
        _entry = State(initialValue: WeightEntry(pricePerUnit: pricePerUnit ?? 0))
        _priceText = State(initialValue: pricePerUnit.map { String(format: "%g", $0) } ?? "")
    }

    private var unit: String { item.unit ?? "kg" }

    public var body: some View {
        let price = Double(priceText) ?? 0
        let current = WeightEntry(pricePerUnit: price).with(mode: entry.mode, text: entry.text)
        ScreenScroll {
            if entry.pricePerUnit == 0 {
                ManiInputField(label: "Price per \(unit)", text: $priceText, placeholder: "₹", keyboard: .decimal)
            }
            ManiSegmentedControl(selection: $entry.mode, options: WeightEntry.Mode.allCases.map { ($0, $0.rawValue) })
            ManiHeroAmount(entry.mode == .weight ? "\(String(format: "%.3f", current.weight)) \(unit)" : "₹" + (entry.text.isEmpty ? "0" : entry.text),
                           caption: entry.mode == .weight ? "= \(String(format: "₹%.2f", current.amount))"
                                                          : "= \(String(format: "%.3f", current.weight)) \(unit)")
            if entry.mode == .weight {
                FlowLayout {
                    ForEach([250, 500, 1000, 2000, 5000], id: \.self) { grams in
                        ManiChip(grams < 1000 ? "\(grams) g" : "\(grams / 1000) \(unit)",
                                 isSelected: abs(current.weight - Double(grams) / 1000) < 0.0001) { entry.preset(grams: grams) }
                    }
                }
            }
            ManiKeypad { key in entry.text = key.apply(to: entry.text, maxDecimals: entry.mode == .weight ? 3 : 2) }
        } bottom: {
            ManiButton("Add to bill · \(String(format: "₹%.2f", current.amount))", isEnabled: current.weight > 0 && price > 0) {
                onAdd(current.weight, price)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension WeightEntry {
    func with(mode: Mode, text: String) -> WeightEntry {
        var copy = self
        copy.mode = mode
        copy.text = text
        return copy
    }
}

// MARK: - Quick item (28)

public struct CustomItemSheet: View {
    private let onAdd: (_ name: String, _ amount: Double, _ category: String, _ save: Bool) -> Void
    @State private var amountText = ""
    @State private var name = ""
    @State private var category = "Misc"
    @State private var saveAsItem = false

    public init(onAdd: @escaping (String, Double, String, Bool) -> Void) {
        self.onAdd = onAdd
    }

    public var body: some View {
        let amount = Double(amountText) ?? 0
        ScreenScroll {
            ScreenSubtitle(text: "Not in your list? Bill it anyway")
            ManiHeroAmount("₹" + (amountText.isEmpty ? "0" : amountText), caption: name.isEmpty ? category : name)
            ManiInputField(label: "Name (optional)", text: $name, placeholder: "Plastic covers")
            FlowLayout {
                ForEach(["Misc", "Groceries", "Snacks", "Service"], id: \.self) { option in
                    ManiChip(option, isSelected: category == option) { category = option }
                }
            }
            ManiToggleRow(title: "Save as new item", subtitle: "Add to inventory for next time", isOn: $saveAsItem)
            ManiKeypad { key in amountText = key.apply(to: amountText) }
        } bottom: {
            ManiButton("Add \(Money.format(amount)) to bill", isEnabled: amount > 0) {
                onAdd(name, amount, category, saveAsItem)
            }
        }
        .navigationTitle("Quick item")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Variant (32)

public struct VariantSheet: View {
    @Environment(\.maniTheme) private var theme
    private let item: InventoryItem
    private let variants: ItemVariants
    private let price: Double
    private let onAdd: (_ variant: String, _ quantity: Int) -> Void
    @State private var size: String
    @State private var colour: String
    @State private var quantityText = "1"

    public init(item: InventoryItem, variants: ItemVariants, price: Double, onAdd: @escaping (String, Int) -> Void) {
        self.item = item
        self.variants = variants
        self.price = price
        self.onAdd = onAdd
        _size = State(initialValue: variants.sizes.first ?? "")
        _colour = State(initialValue: variants.colours.first?.name ?? "")
    }

    private var quantity: Int { max(1, Int(quantityText) ?? 1) }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(Money.format(price)) · \(item.currentStock) in stock")
            if !variants.sizes.isEmpty {
                SectionHeader(title: "Size")
                ManiSegmentedControl(selection: $size, options: variants.sizes.map { ($0, $0) })
            }
            if !variants.colours.isEmpty {
                SectionHeader(title: "Colour")
                ManiSwatchRow(options: variants.colours.map { ($0.name, $0.name, Color(hex: $0.hex)) }, selection: $colour)
            }
            ManiInputField(label: "Quantity", text: $quantityText, keyboard: .number)
        } bottom: {
            ManiButton("Add to bill · \(Money.format(price * Double(quantity)))") {
                onAdd([size, colour].filter { !$0.isEmpty }.joined(separator: " · "), quantity)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Color {
    /// "#B91C1C" → Color; falls back to grey.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(cleaned, radix: 16) ?? 0x9CA3AF
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

// MARK: - Line edit (33)

public struct LineEditView: View {
    @Bindable private var viewModel: LineEditViewModel
    private let showsWarranty: Bool
    private let onSave: (CartItem) -> Void
    private let onRemove: () -> Void

    public init(viewModel: LineEditViewModel, showsWarranty: Bool, onSave: @escaping (CartItem) -> Void, onRemove: @escaping () -> Void) {
        self.viewModel = viewModel
        self.showsWarranty = showsWarranty
        self.onSave = onSave
        self.onRemove = onRemove
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(Money.format(viewModel.original.category.sellPrice ?? viewModel.price)) · \(viewModel.original.category.currentStock) in stock")
            if viewModel.original.weight == nil {
                SectionHeader(title: "Quantity")
                HStack(spacing: ManiSpacing.md) {
                    ManiButton("−", kind: .outline) { viewModel.decrement() }
                    ManiHeroAmount("\(viewModel.quantity)")
                    ManiButton("+", kind: .outline) { viewModel.increment() }
                }
            }
            ManiInputField(label: "Price", text: $viewModel.priceText, placeholder: "₹", keyboard: .decimal)
            SectionHeader(title: "Item discount")
            ManiSegmentedControl(selection: $viewModel.discountMode, options: LineDiscountMode.allCases.map { ($0, $0.rawValue) })
            if viewModel.discountMode != .none {
                ManiInputField(label: "Discount", text: $viewModel.discountText,
                               placeholder: viewModel.discountMode == .amount ? "₹" : "%", keyboard: .decimal)
            }
            if showsWarranty {
                ManiToggleRow(title: "Warranty",
                              subtitle: "\(viewModel.warrantyMonths) months · till \(viewModel.warrantyEnds.formatted(date: .numeric, time: .omitted))",
                              isOn: $viewModel.hasWarranty)
                if viewModel.hasWarranty {
                    Stepper("\(viewModel.warrantyMonths) months", value: $viewModel.warrantyMonths, in: 1...60)
                }
            }
            ManiKeyValueSummary(rows: [ManiKeyValue("Line total", Money.format(viewModel.lineTotal))])
        } bottom: {
            VStack(spacing: ManiSpacing.sm) {
                ManiButton(viewModel.isNew ? "Add to bill" : "Update line", isEnabled: viewModel.isValid) {
                    onSave(viewModel.build())
                }
                if !viewModel.isNew {
                    ManiButton("Remove from bill", icon: .trash, kind: .outline, action: onRemove)
                }
            }
        }
        .navigationTitle(viewModel.original.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Bill discount (34)

public struct BillDiscountView: View {
    @Bindable private var viewModel: BillDiscountViewModel
    private let onApply: (_ amount: Double, _ percent: Double?) -> Void

    public init(viewModel: BillDiscountViewModel, onApply: @escaping (Double, Double?) -> Void) {
        self.viewModel = viewModel
        self.onApply = onApply
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Subtotal \(Money.format(viewModel.subtotal))")
            ManiSegmentedControl(selection: $viewModel.mode, options: BillDiscountViewModel.Mode.allCases.map { ($0, $0.rawValue) })
            ManiHeroAmount(viewModel.mode == .percent ? "\(viewModel.valueText.isEmpty ? "0" : viewModel.valueText)%"
                                                      : "₹" + (viewModel.valueText.isEmpty ? "0" : viewModel.valueText),
                           caption: "−\(Money.format(viewModel.amount)) · new total \(Money.format(viewModel.newTotal))")
            FlowLayout {
                ForEach([5.0, 10.0, 15.0], id: \.self) { percent in
                    ManiChip("\(Int(percent))%", isSelected: viewModel.mode == .percent && Double(viewModel.valueText) == percent) {
                        viewModel.preset(percent)
                    }
                }
                if viewModel.roundDownTarget < viewModel.subtotal {
                    ManiChip("Round to \(Money.format(viewModel.roundDownTarget))") { viewModel.roundTotal() }
                }
            }
            ManiNote("You can give up to \(Int(viewModel.limitPercent))%. Above that a manager approves on this phone with their PIN.",
                     kind: viewModel.needsApproval ? .warning : .info)
            if viewModel.needsApproval {
                SectionHeader(title: "Manager PIN")
                ManiCodeField(length: 4, code: viewModel.managerPin, secure: true)
                if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
                ManiKeypad(showsDecimal: false) { key in
                    switch key {
                    case .digit(let value): _ = viewModel.managerKey(.digit(value))
                    case .backspace: _ = viewModel.managerKey(.backspace)
                    case .decimal: break
                    }
                }
            } else {
                ManiKeypad(showsDecimal: viewModel.mode == .amount) { key in viewModel.valueText = key.apply(to: viewModel.valueText) }
            }
        } bottom: {
            HStack(spacing: ManiSpacing.sm) {
                ManiButton("Remove", kind: .outline) { onApply(0, nil) }
                ManiButton("Apply discount", isEnabled: viewModel.canApply) {
                    onApply(viewModel.amount, viewModel.appliedPercent)
                }
            }
        }
        .navigationTitle("Bill discount")
        .navigationBarTitleDisplayMode(.inline)
    }
}
