//
//  POSExtraScreens.swift
//  ApoorvaModules
//
//  Jewellery design detail (36), catalog share (37), parlour packages (39),
//  return / exchange (52) and barcode scan (53).
//

import SwiftUI
import ApoorvaModels
import ManiSwiftUIComponents
#if canImport(VisionKit) && os(iOS)
import VisionKit
#endif

// MARK: - Jewellery design detail (36)

public struct JewelItemView: View {
    @Environment(\.maniTheme) private var theme
    private let item: InventoryItem
    private let price: Double?
    private let similar: [InventoryItem]
    private let onAdd: () -> Void
    private let onOpen: (InventoryItem) -> Void

    public init(item: InventoryItem, price: Double?, similar: [InventoryItem], onAdd: @escaping () -> Void,
                onOpen: @escaping (InventoryItem) -> Void) {
        self.item = item
        self.price = price
        self.similar = similar
        self.onAdd = onAdd
        self.onOpen = onOpen
    }

    private var photos: [URL] { (item.imageURLs ?? []).compactMap(URL.init(string:)) }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: [item.designCode, item.categoryId].compactMap { $0 }.joined(separator: " · "))
            TabView {
                if photos.isEmpty {
                    placeholder
                } else {
                    ForEach(photos, id: \.self) { url in
                        AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { placeholder }
                    }
                }
            }
            .tabViewStyle(.page)
            .frame(height: 260)
            .background(theme.accent.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: theme.radii.card))

            ManiKeyValueSummary(rows: [
                ManiKeyValue("Price", price.map(Money.format) ?? "Not set"),
                ManiKeyValue("Stock", "\(item.currentStock)")
            ], emphasizeLast: false)

            if !similar.isEmpty {
                SectionHeader(title: "Similar designs")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ManiSpacing.sm) {
                        ForEach(similar) { other in
                            ManiChip("\(other.name)\(other.designCode.map { " · \($0)" } ?? "")") { onOpen(other) }
                        }
                    }
                }
            }
            ShareLink(item: "\(item.name)\(item.designCode.map { " (\($0))" } ?? "") · \(price.map(Money.format) ?? "")") {
                ManiStatusBadge("Share", kind: .neutral)
            }
        } bottom: {
            ManiButton("Add to bill · \(price.map(Money.format) ?? "set price")", action: onAdd)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var placeholder: some View {
        ManiSwiftUIComponents.IconView(.sparkles, size: 48, color: theme.accent.accent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Catalog share (37)

public struct CatalogShareView: View {
    @Environment(\.maniTheme) private var theme
    private let items: [InventoryItem]
    private let categoryNames: [String: String]
    @State private var selected: Set<String> = []
    @State private var category: String?
    @State private var showsPrices = true

    public init(items: [InventoryItem], categoryNames: [String: String] = [:]) {
        self.items = items
        self.categoryNames = categoryNames
    }

    private var visible: [InventoryItem] {
        category.map { id in items.filter { $0.categoryId == id } } ?? items
    }

    /// The WhatsApp message, with photo links where items have them.
    var message: String {
        let chosen = items.filter { selected.contains($0.id) }
        var lines = ["Designs for you:"]
        for item in chosen {
            var line = "• \(item.name)"
            if let code = item.designCode { line += " (\(code))" }
            if showsPrices, let price = item.sellPrice { line += " – \(Money.format(price))" }
            lines.append(line)
            if let photo = item.imageURLs?.first { lines.append("  \(photo)") }
        }
        lines.append("Reply with the code to order.")
        return lines.joined(separator: "\n")
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "\(selected.count) designs selected")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ManiSpacing.sm) {
                    ManiChip("All", isSelected: category == nil) { category = nil }
                    ForEach(Array(Set(items.compactMap(\.categoryId))).sorted(), id: \.self) { id in
                        ManiChip(categoryNames[id] ?? id, isSelected: category == id) { category = id }
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: ManiSpacing.sm), GridItem(.flexible())], spacing: ManiSpacing.sm) {
                ForEach(visible) { item in
                    Button {
                        if selected.contains(item.id) { selected.remove(item.id) } else { selected.insert(item.id) }
                    } label: {
                        ManiCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(theme.typography.body.weight(.medium)).foregroundStyle(theme.base.text)
                                    Text([item.designCode, item.sellPrice.map(Money.format)].compactMap { $0 }.joined(separator: " · "))
                                        .font(theme.typography.secondary).foregroundStyle(theme.base.textSecondary)
                                }
                                Spacer()
                                if selected.contains(item.id) {
                                    ManiSwiftUIComponents.IconView(.checkCircle, size: 18, color: theme.accent.accent)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            ManiToggleRow(title: "Show prices", subtitle: "Hide for wholesale buyers", isOn: $showsPrices)
        } bottom: {
            ShareLink(item: message) {
                Text("Share \(selected.count) designs on WhatsApp")
                    .font(theme.typography.body.weight(.semibold))
                    .foregroundStyle(theme.accent.on)
                    .frame(maxWidth: .infinity, minHeight: ManiTouchTarget.minimum)
                    .background(selected.isEmpty ? theme.base.border : theme.accent.accent)
                    .clipShape(RoundedRectangle(cornerRadius: theme.radii.button))
            }
            .disabled(selected.isEmpty)
        }
        .navigationTitle("Share catalog")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Packages (39)

public struct PackagesView: View {
    @Bindable private var viewModel: PackagesViewModel
    private let onSell: (CartItem) -> Void
    private let onUsed: () -> Void

    public init(viewModel: PackagesViewModel, onSell: @escaping (CartItem) -> Void, onUsed: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onSell = onSell
        self.onUsed = onUsed
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: viewModel.customerPhone == nil ? "Attach a customer to use their packages" : viewModel.customerName)
            if !viewModel.owned.isEmpty {
                RowsCard {
                    ForEach(viewModel.owned) { package in
                        ManiListRow(title: package.name,
                                    subtitle: package.sessions > 0
                                        ? "\(package.sessionsUsed) of \(package.sessions) used · valid till \(package.validUntil.shortDay)"
                                        : "Valid till \(package.validUntil.shortDay)",
                                    value: Money.format(package.price),
                                    status: package.isActive ? ("Active", .success) : (package.isExpired ? ("Expired", .error) : ("Used up", .warning)))
                    }
                }
            }
            SectionHeader(title: "Sell a new package")
            if viewModel.catalog.isEmpty {
                ManiEmptyState(icon: .gift, title: "No packages yet", message: "Add packages and memberships in Admin → Features.")
            } else {
                RowsCard {
                    ForEach(viewModel.catalog) { package in
                        ManiListRow(title: package.name,
                                    subtitle: [package.details, package.sessions > 0 ? "\(package.sessions) sessions" : nil, "\(package.validityDays) days"]
                                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                                    value: Money.format(package.price)) { onSell(viewModel.cartLine(for: package)) }
                    }
                }
            }
            if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
        } bottom: {
            if let active = viewModel.firstActive {
                ManiButton("Use 1 session today") {
                    Task { if await viewModel.useSession(active) { onUsed() } }
                }
            }
        }
        .navigationTitle("Packages")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - Return / exchange (52)

public struct ReturnView: View {
    @Bindable private var viewModel: ReturnViewModel
    private let onReturned: (Sale) -> Void
    private let onExchange: (PosCart) -> Void

    public init(viewModel: ReturnViewModel, onReturned: @escaping (Sale) -> Void, onExchange: @escaping (PosCart) -> Void) {
        self.viewModel = viewModel
        self.onReturned = onReturned
        self.onExchange = onExchange
    }

    public var body: some View {
        ScreenScroll {
            if let sale = viewModel.sale {
                ScreenSubtitle(text: "Bill \(sale.displayNumber) · \(sale.timestamp.shortDay)")
                RowsCard {
                    ForEach(viewModel.lines) { line in
                        ManiToggleRow(title: "\(line.item.categoryName) × \(line.item.qty)",
                                      subtitle: Money.format(line.item.totalAmount),
                                      isOn: Binding(get: { line.isSelected }, set: { _ in viewModel.toggle(line.id) }))
                        if line.isSelected && line.item.qty > 1 {
                            Stepper("Return \(line.returnQty)", value: Binding(get: { line.returnQty },
                                                                               set: { viewModel.setQty($0, for: line.id) }),
                                    in: 1...line.item.qty)
                        }
                    }
                }
                ManiInputField(label: "Reason", text: $viewModel.reason, placeholder: "Size mismatch")
                ManiSegmentedControl(selection: $viewModel.refund, options: viewModel.availableRefunds.map { ($0, $0.rawValue) })
                ManiKeyValueSummary(rows: [ManiKeyValue(viewModel.refund == .exchange ? "Credit towards new bill" : "Refund",
                                                        Money.format(viewModel.refundAmount))])
                if sale.isCancelled { ManiNote("This bill is cancelled, so it can't be returned.", kind: .warning) }
                if let error = viewModel.errorMessage { ManiNote(error, kind: .error) }
            } else {
                ProgressView()
            }
        } bottom: {
            ManiButton(viewModel.refund == .exchange ? "Pick new items" : "Process return",
                       isLoading: viewModel.isProcessing, isEnabled: viewModel.canProcess) {
                if viewModel.refund == .exchange {
                    onExchange(viewModel.exchangeCart())
                } else {
                    Task { if let sale = await viewModel.process() { onReturned(sale) } }
                }
            }
        }
        .navigationTitle("Return / exchange")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
    }
}

// MARK: - Scan (53)

/// Continuous barcode scan. Uses VisionKit's live scanner where supported; otherwise type the code.
public struct ScanView: View {
    @Bindable private var viewModel: POSViewModel
    private let onDone: () -> Void
    @State private var scanned: [InventoryItem] = []
    @State private var manualCode = ""
    @State private var message: String?
    @State private var lastCode: (code: String, at: Date)?

    public init(viewModel: POSViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
    }

    private func handle(_ code: String) {
        // The live scanner reports the same code many times a second.
        if let lastCode, lastCode.code == code, Date().timeIntervalSince(lastCode.at) < 1.5 { return }
        lastCode = (code, Date())
        if let item = viewModel.addScanned(barcode: code) {
            scanned.insert(item, at: 0)
            message = nil
        } else {
            message = "No item with barcode \(code). Add it in Stock → Items."
        }
    }

    public var body: some View {
        ScreenScroll {
            ScreenSubtitle(text: "Point the camera at a barcode")
            scanner
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                ManiInputField(label: "Or type the code", text: $manualCode, keyboard: .number)
                ManiButton("Add", kind: .outline, isEnabled: !manualCode.isEmpty) {
                    handle(manualCode)
                    manualCode = ""
                }
                .frame(width: 88)
            }
            if let message { ManiNote(message, kind: .warning) }
            if !scanned.isEmpty {
                SectionHeader(title: "Scanned")
                RowsCard {
                    ForEach(Array(scanned.enumerated()), id: \.offset) { _, item in
                        ManiListRow(title: item.name, subtitle: item.barcode, value: item.sellPrice.map(Money.format))
                    }
                }
            }
        } bottom: {
            ManiActionBar(summaryText: "\(viewModel.cart.items.count) items",
                          primaryTitle: "Done · \(Money.format(viewModel.totalPayable))", primaryAction: onDone)
        }
        .navigationTitle("Scan")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var scanner: some View {
        #if canImport(VisionKit) && os(iOS)
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            BarcodeScanner(onCode: handle)
        } else {
            ManiEmptyState(icon: .camera, title: "Camera scanning isn't available",
                           message: "Allow camera access in Settings, or type the code below.")
        }
        #else
        ManiEmptyState(icon: .camera, title: "Camera scanning isn't available", message: "Type the code below.")
        #endif
    }
}

#if canImport(VisionKit) && os(iOS)
private struct BarcodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .fast,
                                                   recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: false,
                                                   isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item, let value = barcode.payloadStringValue {
                    Task { @MainActor in self.onCode(value) }
                }
            }
        }
    }
}
#endif
