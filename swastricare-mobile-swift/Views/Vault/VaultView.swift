//
//  VaultView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct VaultView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.vaultViewModel
    
    // MARK: - Local State
    
    @State private var showDocumentPicker = false
    @State private var selectedDocument: MedicalDocument?
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Category Filter
                categoryFilter
                
                // Documents List
                if viewModel.isLoading && viewModel.documents.isEmpty {
                    loadingView
                } else if viewModel.filteredDocuments.isEmpty {
                    emptyState
                } else {
                    documentsGrid
                }
            }
            .padding(.top)
        }
        .navigationTitle("Medical Vault")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchQuery, prompt: "Search documents...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showDocumentPicker = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
        }
        .task {
            await viewModel.loadDocuments()
        }
        .refreshable {
            await viewModel.loadDocuments()
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { fileName, data in
                viewModel.prepareUpload(fileName: fileName, fileData: data)
            }
        }
        .sheet(isPresented: $viewModel.showUploadSheet) {
            uploadSheet
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document, viewModel: viewModel)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Subviews
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryChip(
                    title: "All",
                    count: viewModel.totalDocuments,
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.setCategory(nil)
                }
                
                ForEach(VaultCategory.allCases) { category in
                    CategoryChip(
                        title: category.rawValue,
                        count: viewModel.documentsByCategory[category] ?? 0,
                        isSelected: viewModel.selectedCategory == category,
                        icon: category.icon,
                        color: category.color
                    ) {
                        viewModel.setCategory(category)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading documents...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Documents")
                .font(.headline)
            
            Text("Upload your first medical document to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showDocumentPicker = true }) {
                Label("Upload Document", systemImage: "arrow.up.doc.fill")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding()
                    .background(PremiumColor.royalBlue)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var documentsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            ForEach(viewModel.filteredDocuments) { document in
                DocumentCard(document: document)
                    .onTapGesture {
                        selectedDocument = document
                    }
            }
        }
        .padding(.horizontal)
    }
    
    private var uploadSheet: some View {
        NavigationStack {
            Form {
                Section("Document Details") {
                    TextField("File Name", text: $viewModel.uploadFileName)
                    
                    Picker("Category", selection: $viewModel.uploadCategory) {
                        ForEach(VaultCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    
                    TextField("Notes (optional)", text: $viewModel.uploadNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                if viewModel.uploadState.isUploading {
                    Section {
                        ProgressView(value: viewModel.uploadState.progress)
                        Text("Uploading... \(Int(viewModel.uploadState.progress * 100))%")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetUploadForm()
                        viewModel.showUploadSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        Task {
                            if await viewModel.uploadDocument() {
                                viewModel.showUploadSheet = false
                            }
                        }
                    }
                    .disabled(!viewModel.canUpload || viewModel.uploadState.isUploading)
                }
            }
        }
    }
}

// MARK: - Supporting Views

private struct CategoryChip: View {
    let title: String
    let count: Int
    var isSelected: Bool
    var icon: String? = nil
    var color: Color = .gray
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(isSelected ? .white : color)
                }
                Text(title)
                Text("(\(count))")
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? AnyShapeStyle(PremiumColor.royalBlue)
                    : AnyShapeStyle(Material.ultraThinMaterial)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

private struct DocumentCard: View {
    let document: MedicalDocument
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: document.icon)
                    .font(.title2)
                    .foregroundColor(document.iconColor)
                
                Spacer()
                
                Text(document.fileType.uppercased())
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            
            Text(document.title)
                .font(.headline)
                .lineLimit(2)
            
            Text(document.category)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(document.formattedDate)
                Spacer()
                Text(document.formattedFileSize)
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding()
        .glass(cornerRadius: 16)
    }
}

private struct DocumentDetailView: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: document.icon)
                            .font(.largeTitle)
                            .foregroundColor(document.iconColor)
                        
                        VStack(alignment: .leading) {
                            Text(document.title)
                                .font(.headline)
                            Text(document.category)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical)
                }
                
                Section("Details") {
                    LabeledContent("Type", value: document.fileType.uppercased())
                    LabeledContent("Size", value: document.formattedFileSize)
                    LabeledContent("Date", value: document.formattedDate)
                    
                    if let notes = document.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .foregroundColor(.secondary)
                            Text(notes)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            if let _ = await viewModel.downloadDocument(document) {
                                // Handle download - open viewer
                            }
                        }
                    }) {
                        Label("Download", systemImage: "arrow.down.circle")
                    }
                    
                    Button(role: .destructive, action: {
                        Task {
                            if await viewModel.deleteDocument(document) {
                                dismiss()
                            }
                        }
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Document Picker View

private struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (String, Data) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .data])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (String, Data) -> Void
        
        init(onPick: @escaping (String, Data) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            let shouldAccess = url.startAccessingSecurityScopedResource()
            defer { if shouldAccess { url.stopAccessingSecurityScopedResource() } }
            
            if let data = try? Data(contentsOf: url) {
                onPick(url.lastPathComponent, data)
            }
        }
    }
}

#Preview {
    NavigationStack {
        VaultView()
    }
}

