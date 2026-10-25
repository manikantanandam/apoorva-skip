//
//  CustomerListView.swift
//  ApoorvaModules
//
//  Created by Manikanta Nandam on 12/10/26.
//

import SwiftUI

public struct CustomerListView: View {
    
    @Bindable var viewModel: CustomerListViewModel
    
    @State private var isShowingFormatSheet = false
    @State private var selectedFormat: FileFormat?
    @State private var exportURL: URL?
    
    public init(viewModel: CustomerListViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(viewModel.customers) { item in
                    CardView {
                        VStack {
                            LabelView(text: item.name)
                            LabelView(text: item.phone)
                            LabelView(text: "\(item.totalSales)")
                            LabelView(text: "\(item.totalAmountSpent)")
                            DescriptionView(
                                title: "Created Date",
                                value: Date(timeIntervalSince1970: item.createdAt)
                                    .toString(format: "dd-MM-yyyy") ?? ""
                            )
                            if let lastPurchaseDate = item.lastPurchaseDate {
                                DescriptionView(
                                    title: "Last Purchased Date",
                                    value: Date(timeIntervalSince1970: lastPurchaseDate)
                                        .toString(format: "dd-MM-yyyy") ?? ""
                                )
                            } else {
                                LabelView(text: "No Purchase")
                            }
                        }
                    }
                }
            }
        }
        .toolbar{
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.forceSync()
                    }
                }) {
                    Label("Sync", systemImage: "arrow.clockwise")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $viewModel.sortOption) {
                        ForEach(CustomerSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    Task {
                        isShowingFormatSheet = true
                    }
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            

        }
        .task {
            await viewModel.prepareDate()
        }
        // 2. Attach the sheet modifier
        .sheet(isPresented: $isShowingFormatSheet) {
            FormatSelectionSheet { format in
                selectedFormat = format
                isShowingFormatSheet = false
                if let url = try? viewModel.export(format: format) {
                    // Small delay ensures the current sheet dismisses cleanly
                    // before iOS triggers the native system share sheet
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.exportURL = url
                    }
                }
            }
            // Sets the sheet to take up roughly half the screen on iOS 16+
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
                .presentationDetents([.medium, .large])
        }
    }
}

// 5. Lightweight UIViewControllerRepresentable helper to bring up the iOS Native Share UI
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Extension to allow URL to safely bind to .sheet(item:)
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

// 3. The isolated Sheet View
struct FormatSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    var onSelect: (FileFormat) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Choose a format to proceed")) {
                    ForEach(FileFormat.allCases) { format in
                        Button(action: { onSelect(format) }) {
                            HStack(spacing: 15) {
                                Image(systemName: format.icon)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                                    .frame(width: 30)
                                
                                VStack(alignment: .leading) {
                                    Text(format == .csv ? "Comma-Separated Values" : "vCard / Contacts")
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(format.rawValue)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundColor(Color.black)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Select Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
