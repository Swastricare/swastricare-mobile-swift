//
//  VaultView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Medical Vault with modern UI design
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

// MARK: - Main Vault View

struct VaultView: View {
    
    // MARK: - ViewModel
    // Use ObservedObject since ViewModel is shared/owned by DependencyContainer
    @ObservedObject private var viewModel = DependencyContainer.shared.vaultViewModel
    
    // MARK: - Local State
    @State private var showAddOptions = false
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedDocument: MedicalDocument?
    @State private var documentForDetails: MedicalDocument?
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: MedicalDocument?
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                vaultAppBar
                contentArea
            }
        }
        .trackScreen("Vault")
        // Documents loaded once in ContentView; use cached data. Pull-to-refresh for manual reload.
        .refreshable {
            await viewModel.loadDocuments(forceRefresh: true)
        }
        .sheet(isPresented: $showAddOptions) {
            AddDocumentSheet(
                onChooseFiles: {
                    showAddOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showDocumentPicker = true
                    }
                },
                onPhotoLibrary: {
                    showAddOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showPhotoPicker = true
                    }
                }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDocumentPicker) {
            MultiDocumentPickerView { files in
                viewModel.prepareMultipleUploads(files: files)
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotos,
            maxSelectionCount: 10,
            matching: .images
        )
        .onChange(of: selectedPhotos) { _, newValue in
            Task { await handleSelectedPhotos(newValue) }
        }
        .sheet(isPresented: $viewModel.showUploadSheet) {
            BatchUploadSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedDocument) { document in
            DocumentViewer(document: document)
        }
        .sheet(item: $documentForDetails) { document in
            DocumentDetailSheet(
                document: document,
                viewModel: viewModel,
                onView: {
                    documentForDetails = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedDocument = document
                    }
                },
                onDelete: { 
                    documentForDetails = nil
                    confirmDelete(document) 
                }
            )
        }
        .alert("Delete Document", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let doc = documentToDelete {
                    Task { await viewModel.deleteDocument(doc) }
                }
            }
        } message: {
            Text("Are you sure you want to delete this document? This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - App Bar
    private var vaultAppBar: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("Medical Vault")
                    .font(.poppins(.bold, size: 22))
                    .foregroundColor(Color(hex: "0F172A"))
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack {
                    Spacer()

                    Menu {
                        Button {
                            showAddOptions = true
                        } label: {
                            Label("Add document", systemImage: "plus")
                        }

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.toggleSelectionMode()
                            }
                        } label: {
                            Label(viewModel.isSelectionMode ? "Cancel Selection" : "Select Documents", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.poppins(.semiBold, size: 16))
                            .foregroundColor(Color(hex: "0F172A"))
                            .frame(width: 40, height: 40)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if viewModel.isSelectionMode {
                selectionBar
                    .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Selection Bar
    private var selectionBar: some View {
        HStack(spacing: 16) {
            Text("\(viewModel.selectedDocuments.count) selected")
                .font(.poppins(.medium, size: 14))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                viewModel.selectAllDocuments()
            } label: {
                Text("Select All")
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(AppColors.aiTeal)
            }
            
            Button(role: .destructive) {
                Task { await deleteSelectedDocuments() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Delete")
                }
                .font(.poppins(.semiBold, size: 14))
                .foregroundColor(.red)
            }
            .disabled(viewModel.selectedDocuments.isEmpty)
            .opacity(viewModel.selectedDocuments.isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .glass(cornerRadius: 16)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        Group {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage, viewModel.documents.isEmpty {
                errorView(error)
            } else if viewModel.documents.isEmpty {
                emptyStateView
            } else {
                documentsContent
            }
        }
    }

    // MARK: - Documents Content
    private var documentsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                StorageCard(
                    usedBytes: Int64(viewModel.documents.reduce(0) { $0 + $1.fileSize }),
                    totalBytes: 1_073_741_824,
                    onAddFiles: { showAddOptions = true }
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)

                CategoryTilesRow(
                    allCount: viewModel.totalDocuments,
                    reportsCount: viewModel.documentsByCategory[.labReports] ?? 0,
                    prescriptionsCount: viewModel.documentsByCategory[.prescriptions] ?? 0,
                    scansCount: viewModel.documentsByCategory[.imaging] ?? 0,
                    selected: viewModel.selectedCategory,
                    onSelectAll: { viewModel.setCategory(nil) },
                    onSelectReports: { viewModel.setCategory(.labReports) },
                    onSelectPrescriptions: { viewModel.setCategory(.prescriptions) },
                    onSelectScans: { viewModel.setCategory(.imaging) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                HStack(alignment: .center) {
                    Text(sectionHeaderTitle)
                        .font(.poppins(.bold, size: 15))
                        .foregroundColor(Color(hex: "0F172A"))

                    Spacer()

                    Text("Sort by: Newest")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(Color(hex: "6B7280"))

                    Button {
                        showAddOptions = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(AppColors.aiTeal)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(AppColors.aiTeal.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 6)

                if viewModel.filteredDocuments.isEmpty {
                    categoryEmptyState
                        .padding(.top, 48)
                        .padding(.bottom, 48)
                } else {
                    Text("\(viewModel.filteredDocuments.count) \(viewModel.filteredDocuments.count == 1 ? "document" : "documents")")
                        .font(.poppins(.regular, size: 12))
                        .foregroundColor(Color(hex: "0F172A").opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)

                    documentListView
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var sectionHeaderTitle: String {
        switch viewModel.selectedCategory {
        case .none: return "All Files"
        case .some(.labReports): return "Reports"
        case .some(.prescriptions): return "Prescriptions"
        case .some(.imaging): return "Scans"
        case .some(let other): return other.rawValue
        }
    }

    private var categoryEmptyState: some View {
        VStack(spacing: 4) {
            Text("No files yet")
                .font(.poppins(.bold, size: 16))
                .foregroundColor(Color(hex: "0F172A"))
            Text("Add your health documents to\nkeep them safe and organized.")
                .font(.poppins(.regular, size: 12))
                .foregroundColor(Color(hex: "6B7280"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Document List View
    private var documentListView: some View {
        VStack(spacing: 0) {
            let docs = viewModel.filteredDocuments
            ForEach(Array(docs.enumerated()), id: \.element.id) { index, document in
                VaultDocumentRow(
                    document: document,
                    isSelectionMode: viewModel.isSelectionMode,
                    isSelected: viewModel.selectedDocuments.contains(document.id ?? UUID()),
                    onTap: {
                        if viewModel.isSelectionMode {
                            if let id = document.id {
                                viewModel.toggleDocumentSelection(id)
                            }
                        } else {
                            selectedDocument = document
                        }
                    },
                    onView: { selectedDocument = document },
                    onEdit: { documentForDetails = document },
                    onDelete: { confirmDelete(document) }
                )

                if index < docs.count - 1 {
                    Rectangle()
                        .fill(Color(hex: "0F172A").opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 16)
                }
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "F7F8FA"))
        )
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 12) {
                        SkeletonShape(height: 56, cornerRadius: 12)
                        SkeletonShape(width: 80, height: 14)
                        SkeletonShape(width: 50, height: 12)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 12)
                    .glass(cornerRadius: 20)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        let accent = AppColors.aiTeal
        return ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(accent.opacity(0.10))
                        .frame(width: 108, height: 108)

                    Image(systemName: "wifi.slash")
                        .font(.poppins(.regular, size: 44))
                        .foregroundColor(accent)
                }

                Spacer().frame(height: 20)

                Text("You're offline")
                    .font(.poppins(.bold, size: 22))
                    .foregroundColor(Color(hex: "0F172A"))

                Spacer().frame(height: 6)

                Text(error)
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 22)

                Button {
                    Task { await viewModel.loadDocuments(forceRefresh: true) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.poppins(.semiBold, size: 14))
                        Text("Try Again")
                            .font(.poppins(.semiBold, size: 15))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(accent)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        let accent = AppColors.aiTeal
        return ScrollView {
            VStack(spacing: 0) {
                Image.androidIcon("vault icon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 180)

                Spacer().frame(height: 8)

                Text("Your vault is empty")
                    .font(.poppins(.bold, size: 22))
                    .foregroundColor(Color(hex: "0F172A"))

                Spacer().frame(height: 6)

                Text("Store your important health documents, reports and prescriptions securely.")
                    .font(.poppins(.regular, size: 13))
                    .foregroundColor(Color(hex: "6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 20)

                VStack(spacing: 14) {
                    VaultFeatureRow(icon: "lock.fill", title: "Secure Storage", description: "Your files are encrypted and protected")
                    VaultFeatureRow(icon: "doc.text.fill", title: "Private Access", description: "Only you can access your files")
                    VaultFeatureRow(icon: "square.and.arrow.up.fill", title: "Easy Sharing", description: "Share files with doctors when needed")
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 22)

                Button {
                    showAddOptions = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.poppins(.semiBold, size: 14))
                        Text("Add Files")
                            .font(.poppins(.semiBold, size: 15))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(accent)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer().frame(height: 10)

                Button {
                    if let url = URL(string: "https://swastricare.com/health-locker") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.poppins(.semiBold, size: 14))
                        Text("Learn more about Vault")
                            .font(.poppins(.semiBold, size: 14))
                    }
                    .foregroundColor(accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(accent.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var files: [(String, Data)] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let fileName = "Photo_\(timestamp)_\(index + 1).jpg"
                files.append((fileName, data))
            }
        }
        
        if !files.isEmpty {
            viewModel.prepareMultipleUploads(files: files)
        }
        
        selectedPhotos = []
    }
    
    private func confirmDelete(_ document: MedicalDocument) {
        documentToDelete = document
        showDeleteConfirmation = true
    }
    
    private func deleteSelectedDocuments() async {
        let selectedIds = viewModel.selectedDocuments
        for id in selectedIds {
            if let doc = viewModel.documents.first(where: { $0.id == id }) {
                await viewModel.deleteDocument(doc)
            }
        }
        viewModel.clearSelection()
        viewModel.toggleSelectionMode()
    }
    
}

// MARK: - Storage Card

private struct StorageCard: View {
    let usedBytes: Int64
    let totalBytes: Int64
    let onAddFiles: () -> Void

    private var percent: Double {
        guard totalBytes > 0 else { return 0 }
        return min(max(Double(usedBytes) / Double(totalBytes), 0), 1)
    }

    private var usedLabel: String {
        if usedBytes >= 1_073_741_824 {
            return String(format: "%.1f GB", Double(usedBytes) / 1_073_741_824.0)
        } else if usedBytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(usedBytes) / 1_048_576.0)
        } else if usedBytes > 0 {
            return "\(max(usedBytes / 1024, 1)) KB"
        } else {
            return "0 MB"
        }
    }

    private var totalLabel: String {
        if totalBytes >= 1_073_741_824 {
            return "\(totalBytes / 1_073_741_824) GB"
        } else {
            return "\(totalBytes / 1_048_576) MB"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Storage Used")
                    .font(.poppins(.medium, size: 12))
                    .foregroundColor(Color(hex: "6B7280"))

                Spacer().frame(height: 4)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(usedLabel)
                        .font(.poppins(.bold, size: 22))
                        .foregroundColor(Color(hex: "0F172A"))

                    Text("/ \(totalLabel)")
                        .font(.poppins(.regular, size: 13))
                        .foregroundColor(Color(hex: "6B7280"))
                }

                Spacer().frame(height: 8)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "D9EFE7"))
                            .frame(height: 5)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(AppColors.aiTeal)
                            .frame(width: geo.size.width * percent, height: 5)
                    }
                }
                .frame(height: 5)

                Spacer().frame(height: 6)

                Text("\(Int(percent * 100))% used")
                    .font(.poppins(.semiBold, size: 11))
                    .foregroundColor(AppColors.aiTeal)
            }

            Image.androidIcon("vault empty illustration")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "EFFAF6"))
        )
    }
}

// MARK: - Category Tiles Row

private struct CategoryTilesRow: View {
    let allCount: Int
    let reportsCount: Int
    let prescriptionsCount: Int
    let scansCount: Int
    let selected: VaultCategory?
    let onSelectAll: () -> Void
    let onSelectReports: () -> Void
    let onSelectPrescriptions: () -> Void
    let onSelectScans: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            CategoryTile(
                icon: "folder.fill",
                label: "All Files",
                count: allCount,
                tint: Color(hex: "38BDF8"),
                background: Color(hex: "EFF8FE"),
                selected: selected == nil,
                onTap: onSelectAll
            )
            CategoryTile(
                icon: "doc.text.fill",
                label: "Reports",
                count: reportsCount,
                tint: Color(hex: "F59E0B"),
                background: Color(hex: "FEF8E1"),
                selected: selected == .labReports,
                onTap: onSelectReports
            )
            CategoryTile(
                icon: "cross.case.fill",
                label: "Prescriptions",
                count: prescriptionsCount,
                tint: Color(hex: "A855F7"),
                background: Color(hex: "F3E8FF"),
                selected: selected == .prescriptions,
                onTap: onSelectPrescriptions
            )
            CategoryTile(
                icon: "photo.fill",
                label: "Scans",
                count: scansCount,
                tint: AppColors.aiTeal,
                background: Color(hex: "E6F8F3"),
                selected: selected == .imaging,
                onTap: onSelectScans
            )
        }
    }
}

private struct CategoryTile: View {
    let icon: String
    let label: String
    let count: Int
    let tint: Color
    let background: Color
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.poppins(.regular, size: 18))
                    .foregroundColor(tint)
                    .frame(height: 22)

                Text(label)
                    .font(.poppins(.semiBold, size: 11))
                    .foregroundColor(Color(hex: "0F172A"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text("\(count)")
                    .font(.poppins(.regular, size: 11))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? tint : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vault Feature Row

private struct VaultFeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.aiTeal.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.poppins(.regular, size: 16))
                    .foregroundColor(AppColors.aiTeal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.poppins(.semiBold, size: 14))
                    .foregroundColor(Color(hex: "0F172A"))

                Text(description)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
            }

            Spacer()
        }
    }
}

// MARK: - Vault Document Row

private struct VaultDocumentRow: View {
    let document: MedicalDocument
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onView: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var categoryColor: Color {
        VaultCategory.allCases.first(where: { $0.rawValue == document.category })?.color ?? AppColors.aiTeal
    }

    private var formattedDate: String {
        guard let date = document.documentDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.poppins(.regular, size: 20))
                        .foregroundColor(isSelected ? AppColors.aiTeal : Color(hex: "0F172A").opacity(0.3))
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(categoryColor.opacity(0.14))
                        .frame(width: 40, height: 40)

                    Image(systemName: document.icon)
                        .font(.poppins(.regular, size: 18))
                        .foregroundColor(categoryColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.poppins(.medium, size: 15))
                        .foregroundColor(Color(hex: "0F172A"))
                        .lineLimit(1)

                    HStack(spacing: 0) {
                        Text(document.category)
                            .font(.poppins(.medium, size: 11))
                            .foregroundColor(categoryColor)

                        if !formattedDate.isEmpty {
                            Text(" • ")
                                .font(.poppins(.regular, size: 11))
                                .foregroundColor(Color(hex: "0F172A").opacity(0.3))
                            Text(formattedDate)
                                .font(.poppins(.regular, size: 11))
                                .foregroundColor(Color(hex: "0F172A").opacity(0.5))
                        }

                        if let doctor = document.doctorName, !doctor.isEmpty {
                            Text(" • ")
                                .font(.poppins(.regular, size: 11))
                                .foregroundColor(Color(hex: "0F172A").opacity(0.3))
                            Text(doctor)
                                .font(.poppins(.regular, size: 11))
                                .foregroundColor(Color(hex: "0F172A").opacity(0.5))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                if !isSelectionMode {
                    Menu {
                        Button {
                            onView()
                        } label: {
                            Label("View", systemImage: "eye")
                        }
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Divider()
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.poppins(.semiBold, size: 14))
                            .foregroundColor(Color(hex: "0F172A").opacity(0.45))
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Document Sheet

private struct AddDocumentSheet: View {
    let onChooseFiles: () -> Void
    let onPhotoLibrary: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let horizontalInset: CGFloat = 20
    private let cardPadding: CGFloat = AppDimensions.cardPadding
    private let cardSpacing: CGFloat = 16
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Add Documents")
                    .font(.poppins(.bold, size: 22))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                
                VStack(spacing: cardSpacing) {
                    // Choose Files Button
                    Button {
                        dismiss()
                        onChooseFiles()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.aiTeal.opacity(0.15))
                                    .frame(width: 52, height: 52)
                                
                                Image(systemName: "folder.fill")
                                    .font(.poppins(.regular, size: 22))
                                    .foregroundColor(AppColors.aiTeal)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Browse Files")
                                    .font(.poppins(.semiBold, size: 16))
                                    .foregroundColor(.primary)
                                
                                Text("PDF, DOC, images and more")
                                    .font(.poppins(.regular, size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.poppins(.semiBold, size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(cardPadding)
                        .glass(cornerRadius: AppDimensions.cardRadius)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    // Photo Library Button
                    Button {
                        dismiss()
                        onPhotoLibrary()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "1BBBCE").opacity(0.15))
                                    .frame(width: 52, height: 52)
                                
                                Image(systemName: "photo.on.rectangle")
                                    .font(.poppins(.regular, size: 22))
                                    .foregroundColor(Color(hex: "1BBBCE"))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Photo Library")
                                    .font(.poppins(.semiBold, size: 16))
                                    .foregroundColor(.primary)
                                
                                Text("Select photos from your library")
                                    .font(.poppins(.regular, size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.poppins(.semiBold, size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(cardPadding)
                        .glass(cornerRadius: AppDimensions.cardRadius)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, 24)
                
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Batch Upload Sheet

private struct BatchUploadSheet: View {
    @ObservedObject var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var folderName: String = ""
    @State private var category: VaultCategory = .labReports
    @State private var description: String = ""
    @State private var documentDate: Date = Date()
    @State private var doctorName: String = ""
    @State private var location: String = ""
    @State private var hasReminder: Bool = false
    @State private var reminderDate: Date = Date()
    @State private var hasAppointment: Bool = false
    @State private var appointmentDate: Date = Date()
    @State private var tags: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Files Section
                Section {
                    ForEach(viewModel.pendingUploads, id: \.fileName) { upload in
                        HStack(spacing: 12) {
                            Image(systemName: upload.icon)
                                .font(.poppins(.regular, size: 20))
                                .foregroundColor(AppColors.aiTeal)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(upload.fileName)
                                    .font(.poppins(.medium, size: 14))
                                    .lineLimit(1)
                                
                                Text(upload.formattedSize)
                                    .font(.poppins(.regular, size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    viewModel.removePendingUpload(upload)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.poppins(.regular, size: 18))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Selected Files (\(viewModel.pendingUploads.count))")
                        Spacer()
                        Text(totalSizeFormatted)
                            .font(.poppins(.regular, size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Folder Name
                Section {
                    TextField("e.g., Annual Checkup, Lab Results", text: $folderName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Folder Name")
                } footer: {
                    Text("Group these documents under a common name")
                }
                
                // Category
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(VaultCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Details
                Section("Details") {
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    
                    DatePicker("Document Date", selection: $documentDate, displayedComponents: .date)
                }
                
                // Provider
                Section("Provider Information") {
                    TextField("Doctor/Provider Name", text: $doctorName)
                    TextField("Hospital/Clinic", text: $location)
                }
                
                // Reminders
                Section("Reminders") {
                    Toggle("Set Reminder", isOn: $hasReminder)
                    if hasReminder {
                        DatePicker("Reminder", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Toggle("Set Appointment", isOn: $hasAppointment)
                    if hasAppointment {
                        DatePicker("Appointment", selection: $appointmentDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                // Tags
                Section {
                    TextField("Tags (comma separated)", text: $tags)
                } footer: {
                    Text("e.g., urgent, follow-up, annual")
                }
                
                // Upload Progress
                if viewModel.uploadState.isUploading {
                    Section {
                        VStack(spacing: 12) {
                            ProgressView(value: viewModel.uploadState.progress)
                                .progressViewStyle(.linear)
                                .tint(AppColors.aiTeal)
                            
                            Text("Uploading \(viewModel.currentUploadIndex + 1) of \(viewModel.totalUploadFiles)...")
                                .font(.poppins(.regular, size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelUpload()
                    }
                    .disabled(viewModel.uploadState.isUploading)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        Task { await uploadAll() }
                    }
                    .font(.poppins(.semiBold, size: 17))
                    .disabled(viewModel.pendingUploads.isEmpty || viewModel.uploadState.isUploading)
                }
            }
        }
        .interactiveDismissDisabled(viewModel.uploadState.isUploading)
    }
    
    private var totalSizeFormatted: String {
        let totalBytes = viewModel.pendingUploads.reduce(0) { $0 + $1.fileData.count }
        return ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
    
    private func uploadAll() async {
        let tagArray = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let sharedMetadata = DocumentMetadata(
            name: "",
            folderName: folderName.isEmpty ? nil : folderName,
            description: description.isEmpty ? nil : description,
            documentDate: documentDate,
            reminderDate: hasReminder ? reminderDate : nil,
            appointmentDate: hasAppointment ? appointmentDate : nil,
            doctorName: doctorName.isEmpty ? nil : doctorName,
            location: location.isEmpty ? nil : location,
            tags: tagArray
        )
        
        viewModel.applySharedMetadata(sharedMetadata, category: category)
        await viewModel.uploadAllDocuments()
    }
}

// MARK: - Document Detail Sheet

private struct DocumentDetailSheet: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    let onView: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var fileURL: URL?
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // Preview Section
                Section {
                    VStack(spacing: 16) {
                        filePreviewView
                        
                        VStack(spacing: 6) {
                            Text(document.title)
                                .font(.poppins(.semiBold, size: 18))
                                .multilineTextAlignment(.center)
                            
                            Text(document.category)
                                .font(.poppins(.regular, size: 14))
                        .foregroundColor(.secondary)
                }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                
                // Timeline
                if document.documentDate != nil || document.reminderDate != nil || document.appointmentDate != nil {
                    Section("Timeline") {
                        if let date = document.documentDate {
                            LabeledRow(icon: "calendar", iconColor: .blue, label: "Document Date", value: formatDate(date))
                        }
                        if let date = document.reminderDate {
                            LabeledRow(icon: "bell.fill", iconColor: .orange, label: "Reminder", value: formatDateTime(date))
                        }
                        if let date = document.appointmentDate {
                            LabeledRow(icon: "calendar.badge.clock", iconColor: .purple, label: "Appointment", value: formatDateTime(date))
                        }
                    }
                    }
                    
                    // Description
                if let desc = document.description, !desc.isEmpty {
                    Section("Description") {
                        Text(desc)
                            .font(.poppins(.regular, size: 17))
                    }
                }
                
                // Provider
                if document.doctorName != nil || document.location != nil {
                    Section("Provider Information") {
                        if let doctor = document.doctorName, !doctor.isEmpty {
                            LabeledContent("Doctor/Provider", value: doctor)
                        }
                        if let location = document.location, !location.isEmpty {
                            LabeledContent("Location", value: location)
                        }
                    }
                }
                
                // Tags
                if let tags = document.tags, !tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                            .font(.poppins(.regular, size: 12))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppColors.aiTeal.opacity(0.1))
                                    .foregroundColor(AppColors.aiTeal)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // File Details
                Section("File Details") {
                    LabeledContent("Type", value: document.fileType.uppercased())
                    LabeledContent("Size", value: document.formattedFileSize)
                    LabeledContent("Uploaded", value: document.formattedDate)
                }
                
                // Actions
                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onView() }
                    } label: {
                        Label("View Document", systemImage: "eye.fill")
                    }
                    
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Edit Details", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDelete() }
                    } label: {
                        Label("Delete Document", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Document Details")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditSheet) {
                EditDocumentSheet(document: document, viewModel: viewModel)
            }
            .task {
                fileURL = await viewModel.getDocumentURL(document)
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private var filePreviewView: some View {
        let isImage = ["jpg", "jpeg", "png", "heic", "gif"].contains(document.fileType.lowercased())
        
        if isImage, let url = fileURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 180)
                        .cornerRadius(12)
                case .failure:
                    fileIconView
                case .empty:
                    ProgressView()
                        .frame(height: 100)
                @unknown default:
                    fileIconView
                }
            }
        } else {
            fileIconView
        }
    }
    
    private var fileIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(document.iconColor.opacity(0.15))
                .frame(width: 100, height: 100)
            
            Image(systemName: document.icon)
                .font(.poppins(.regular, size: 40))
                .foregroundColor(document.iconColor)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Labeled Row

private struct LabeledRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.poppins(.regular, size: 14))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.poppins(.regular, size: 12))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.poppins(.regular, size: 15))
            }
        }
    }
}

// MARK: - Edit Document Sheet

private struct EditDocumentSheet: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var description: String
    @State private var documentDate: Date?
    @State private var reminderDate: Date?
    @State private var appointmentDate: Date?
    @State private var doctorName: String
    @State private var location: String
    @State private var tags: String
    @State private var isSaving = false
    
    init(document: MedicalDocument, viewModel: VaultViewModel) {
        self.document = document
        self.viewModel = viewModel
        
        _name = State(initialValue: document.title)
        _description = State(initialValue: document.description ?? "")
        _documentDate = State(initialValue: document.documentDate)
        _reminderDate = State(initialValue: document.reminderDate)
        _appointmentDate = State(initialValue: document.appointmentDate)
        _doctorName = State(initialValue: document.doctorName ?? "")
        _location = State(initialValue: document.location ?? "")
        _tags = State(initialValue: document.tags?.joined(separator: ", ") ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Document Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                
                Section("Timeline") {
                    DatePicker("Document Date", selection: Binding(
                        get: { documentDate ?? Date() },
                        set: { documentDate = $0 }
                    ), displayedComponents: .date)
                    
                    Toggle("Set Reminder", isOn: Binding(
                        get: { reminderDate != nil },
                        set: { reminderDate = $0 ? Date() : nil }
                    ))
                    
                    if reminderDate != nil {
                        DatePicker("Reminder", selection: Binding(
                            get: { reminderDate ?? Date() },
                            set: { reminderDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Toggle("Set Appointment", isOn: Binding(
                        get: { appointmentDate != nil },
                        set: { appointmentDate = $0 ? Date() : nil }
                    ))
                    
                    if appointmentDate != nil {
                        DatePicker("Appointment", selection: Binding(
                            get: { appointmentDate ?? Date() },
                            set: { appointmentDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                
                Section("Provider Information") {
                    TextField("Doctor/Provider Name", text: $doctorName)
                    TextField("Location/Clinic", text: $location)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                
                Section("Tags") {
                    TextField("Tags (comma separated)", text: $tags)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            }
            .listSectionSpacing(16)
            .navigationTitle("Edit Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveChanges() }
                    }
                    .disabled(isSaving || name.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() async {
        isSaving = true
        
        let tagArray = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let metadata = DocumentMetadata(
            name: name,
            description: description.isEmpty ? nil : description,
            documentDate: documentDate,
            reminderDate: reminderDate,
            appointmentDate: appointmentDate,
            doctorName: doctorName.isEmpty ? nil : doctorName,
            location: location.isEmpty ? nil : location,
            tags: tagArray
        )
        
        do {
            _ = try await viewModel.updateDocument(document, metadata: metadata)
            await viewModel.loadDocuments(forceRefresh: true)
            dismiss()
        } catch {
            print("Failed to update: \(error)")
        }
        
        isSaving = false
    }
}


// MARK: - Multi Document Picker

private struct MultiDocumentPickerView: UIViewControllerRepresentable {
    let onPick: ([(String, Data)]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let contentTypes: [UTType] = [
            .pdf, .image, .jpeg, .png, .heic, .gif, .tiff, .bmp,
            .text, .plainText, .rtf, .data, .item, .content
        ]
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([(String, Data)]) -> Void
        
        init(onPick: @escaping ([(String, Data)]) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var files: [(String, Data)] = []
            
            for url in urls {
                let shouldAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldAccess { url.stopAccessingSecurityScopedResource() } }
                
                if let data = try? Data(contentsOf: url), !data.isEmpty {
                    files.append((url.lastPathComponent, data))
                    print("✅ Loaded: \(url.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
                }
            }
            
            if !files.isEmpty {
                onPick(files)
            }
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions().width, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VaultView()
    }
}
