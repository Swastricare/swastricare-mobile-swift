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
    @State private var selectedFolder: DocumentFolder?
    @State private var showFilterSheet = false
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Premium Background
            PremiumBackground()
            
            VStack(spacing: 0) {
                // Custom App Bar
                vaultAppBar
                
                // Content Area
                contentArea
            }
            
            // Floating Add Button
            if !viewModel.isSelectionMode {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                floatingAddButton
            }
        }
            }
        }
        .onAppear {
            AppAnalyticsService.shared.logScreen("Vault")
        }
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
        .sheet(item: $selectedFolder) { folder in
            FolderDetailSheet(
                folder: folder,
                viewModel: viewModel,
                onViewDocument: { doc in
                    selectedFolder = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedDocument = doc
                    }
                },
                onDocumentInfo: { doc in
                    selectedFolder = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        documentForDetails = doc
                    }
                },
                onDeleteDocument: { doc in
                    selectedFolder = nil
                    confirmDelete(doc)
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
        VStack(spacing: 12) {
            // Top Row - Title and Actions
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Medical Vault")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("\(viewModel.totalDocuments) documents • \(viewModel.totalStorageFormatted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Two Round Buttons
                HStack(spacing: 12) {
                    // View By Button
                    Menu {
                        Button {
                            viewModel.setViewMode(.folders)
                        } label: {
                            Label("Folders", systemImage: "folder.fill")
                            if viewModel.viewMode == .folders {
                                Image(systemName: "checkmark")
                            }
                        }
                        
                        Button {
                            viewModel.setViewMode(.timeline)
                        } label: {
                            Label("Timeline", systemImage: "calendar")
                            if viewModel.viewMode == .timeline {
                                Image(systemName: "checkmark")
                            }
                        }
                        
                        Button {
                            viewModel.setViewMode(.list)
                        } label: {
                            Label("List", systemImage: "list.bullet")
                            if viewModel.viewMode == .list {
                                Image(systemName: "checkmark")
                            }
                        }
                    } label: {
                        Image(systemName: viewModeIcon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(UIColor.secondarySystemBackground)))
                    }
                    
                    // Sort & More Button
                    Menu {
                        // Sort Options
                        Section("Sort By") {
                            Button {
                                viewModel.setSortOrder(.dateDescending)
                            } label: {
                                Label("Newest First", systemImage: "arrow.down")
                            }
                            
                            Button {
                                viewModel.setSortOrder(.dateAscending)
                            } label: {
                                Label("Oldest First", systemImage: "arrow.up")
                            }
                            
                            Button {
                                viewModel.setSortOrder(.nameAscending)
                            } label: {
                                Label("Name (A-Z)", systemImage: "textformat.abc")
                            }
                            
                            Button {
                                viewModel.setSortOrder(.sizeDescending)
                            } label: {
                                Label("File Size", systemImage: "doc.fill")
                            }
                        }
                        
                        Divider()
                        
                        // Select & Delete
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                viewModel.toggleSelectionMode()
                            }
                        } label: {
                            Label(viewModel.isSelectionMode ? "Cancel Selection" : "Select Documents", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color(UIColor.secondarySystemBackground)))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Search Bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                TextField("Search documents...", text: $viewModel.searchQuery)
                    .font(.system(size: 16))
                
                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glass(cornerRadius: 14)
            .padding(.horizontal, 20)
            
            // Category Filter Pills
            categoryFilterPills
            
            // Selection Bar (if in selection mode)
            if viewModel.isSelectionMode {
                selectionBar
            }
        }
        .padding(.bottom, 8)
    }
    
    // View mode icon helper
    private var viewModeIcon: String {
        switch viewModel.viewMode {
        case .folders: return "folder.fill"
        case .timeline: return "calendar"
        case .list: return "list.bullet"
        }
    }
    
    // MARK: - Category Filter Pills
    private var categoryFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // All Category
                FilterPill(
                    title: "All",
                    count: viewModel.totalDocuments,
                    isSelected: viewModel.selectedCategory == nil,
                    color: Color(hex: "2E3192")
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.setCategory(nil)
                    }
                }
                
                // Category Pills
                ForEach(VaultCategory.allCases) { category in
                    FilterPill(
                        title: category.rawValue,
                        count: viewModel.documentsByCategory[category] ?? 0,
                        isSelected: viewModel.selectedCategory == category,
                        icon: category.icon,
                        color: category.color
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.setCategory(category)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Selection Bar
    private var selectionBar: some View {
        HStack(spacing: 16) {
            Text("\(viewModel.selectedDocuments.count) selected")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button {
                viewModel.selectAllDocuments()
            } label: {
                Text("Select All")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "2E3192"))
            }
            
            Button(role: .destructive) {
                Task { await deleteSelectedDocuments() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                    Text("Delete")
                }
                .font(.system(size: 14, weight: .semibold))
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
            } else if viewModel.filteredDocuments.isEmpty {
                emptyStateView
            } else {
                documentsContent
            }
        }
    }
    
    // MARK: - Documents Content
    private var documentsContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch viewModel.viewMode {
                case .folders:
                    foldersGridView
                case .timeline:
                    timelineView
                case .list:
                    documentListView
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }
    
    // MARK: - Folders Grid View
    private var foldersGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.groupedDocuments) { folder in
                FolderCard(folder: folder) {
                    selectedFolder = folder
                }
            }
        }
    }
    
    // MARK: - Timeline View
    private var timelineView: some View {
        let grouped = groupTimelineItemsByDate(viewModel.timelineItems)
        let sortedDates = grouped.keys.sorted(by: >)
        
        return LazyVStack(spacing: 24) {
            ForEach(sortedDates, id: \.self) { date in
                TimelineDateSection(
                    date: date,
                    items: grouped[date] ?? [],
                    onDocumentTap: { doc in selectedDocument = doc },
                    onDocumentInfo: { doc in documentForDetails = doc }
                )
            }
        }
    }
    
    // MARK: - Document List View
    private var documentListView: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filteredDocuments) { document in
                DocumentCard(
                    document: document,
                    viewModel: viewModel,
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
                    onInfo: { documentForDetails = document },
                    onDelete: { confirmDelete(document) }
                )
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "2E3192").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color(hex: "2E3192"))
            }
            
            VStack(spacing: 8) {
                Text("Loading Documents")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Please wait while we fetch your medical records")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Error View
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("Failed to Load")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    }
                    
            Button {
                Task { await viewModel.loadDocuments(forceRefresh: true) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Color(hex: "2E3192"))
                .clipShape(Capsule())
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "2E3192").opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "2E3192"))
            }
            
            VStack(spacing: 8) {
                Text("No Documents Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Upload your medical records, prescriptions,\nand lab reports to keep them organized")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Button {
            //     showAddOptions = true
            // } label: {
            //     HStack(spacing: 8) {
            //         Image(systemName: "plus")
            //         Text("Add Your First Document")
            //     }
            //     .font(.system(size: 16, weight: .semibold))
            //     .foregroundColor(.white)
            //     .padding(.horizontal, 32)
            //     .padding(.vertical, 14)
            //     .background(Color(hex: "2E3192"))
            //     .clipShape(Capsule())
            // }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Floating Add Button
    private var floatingAddButton: some View {
        Button {
            showAddOptions = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                Text("Add")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "4D9E9E9E"))
            .clipShape(Capsule())
            .shadow(color: Color(hex: "2E3192").opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
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
    
    private func groupTimelineItemsByDate(_ items: [TimelineItem]) -> [Date: [TimelineItem]] {
        let calendar = Calendar.current
        return Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.date)
        }
    }
}

// MARK: - Filter Pill Component

private struct FilterPill: View {
    let title: String
    let count: Int
    var isSelected: Bool
    var icon: String? = nil
    var color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.15))
                    )
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Folder Card Component

private struct FolderCard: View {
    let folder: DocumentFolder
    let onTap: () -> Void
    
    private var folderColor: Color {
        let stableHash = abs(folder.id.hashValue)
        return stableHash % 2 == 0 ? Color(hex: "2E3192") : Color(hex: "1BBBCE")
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Folder Icon with Badge
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        // Shadow folder
                        Image(systemName: "folder.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(folderColor.opacity(0.2))
                            .offset(x: 2, y: 2)
                        
                        // Main folder
                        Image(systemName: "folder.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(folderColor)
                    }
                    
                    // File count badge
                    if folder.fileCount > 0 {
                        Text("\(folder.fileCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(
                                Circle()
                                    .fill(Color(hex: "2E3192"))
                            )
                            .offset(x: 8, y: -4)
                    }
                }
                
                // Folder Info
                VStack(spacing: 4) {
                    Text(folder.folderTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    
                    Text(folder.shortSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .glass(cornerRadius: 20)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Document Card Component

private struct DocumentCard: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onInfo: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnailURL: URL?
    
    private var isImage: Bool {
        ["jpg", "jpeg", "png", "heic", "gif"].contains(document.fileType.lowercased())
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection or Thumbnail
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? Color(hex: "2E3192") : .secondary)
                        .frame(width: 44, height: 44)
                } else {
                    thumbnailView
                }
                
                // Document Info
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(document.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Category and Date
                    HStack(spacing: 8) {
                        // Category badge
                        Text(document.category)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(categoryColor(document.category))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(categoryColor(document.category).opacity(0.15))
                            )
                        
                        // Date
                        if let docDate = document.documentDate {
                            Text(formatDate(docDate))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Metadata (Doctor, Location)
                    HStack(spacing: 12) {
                        if let doctor = document.doctorName, !doctor.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                Text(doctor)
                                    .font(.system(size: 11))
                            }
                                .foregroundColor(.secondary)
                    }
                    
                    if let location = document.location, !location.isEmpty {
                        HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                .font(.system(size: 10))
                            Text(location)
                                    .font(.system(size: 11))
                            }
                                        .foregroundColor(.secondary)
                                }
                            }
                    .lineLimit(1)
                }
                
                Spacer()
                
                // Info Button
                if !isSelectionMode {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .glass(cornerRadius: 16)
                    .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: "2E3192") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("Open", systemImage: "eye")
            }
            
            Button {
                onInfo()
            } label: {
                Label("Details", systemImage: "info.circle")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .task(id: document.id) {
            if isImage {
                thumbnailURL = await viewModel.getDocumentURL(document)
            }
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(document.iconColor.opacity(0.12))
                .frame(width: 56, height: 56)
            
            if isImage, let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        fileIcon
                    case .empty:
                        ProgressView()
                            .frame(width: 56, height: 56)
                    @unknown default:
                        fileIcon
                    }
                }
            } else {
                fileIcon
            }
        }
    }
    
    private var fileIcon: some View {
            Image(systemName: document.icon)
            .font(.system(size: 24))
            .foregroundColor(document.iconColor.opacity(0.8))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func categoryColor(_ category: String) -> Color {
        if let vaultCategory = VaultCategory.allCases.first(where: { $0.rawValue == category }) {
            return vaultCategory.color
        }
        return Color(hex: "2E3192")
    }
}

// MARK: - Timeline Date Section

private struct TimelineDateSection: View {
    let date: Date
    let items: [TimelineItem]
    let onDocumentTap: (MedicalDocument) -> Void
    let onDocumentInfo: (MedicalDocument) -> Void
    
    private var relativeDateText: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date Header
            HStack(spacing: 12) {
                // Date Circle
                VStack(spacing: 2) {
                    Text(dayOfMonth)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(hex: "2E3192"))
                    
                    Text(monthAbbr)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, height: 50)
                .glass(cornerRadius: 14)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(relativeDateText)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Timeline Items
            VStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    TimelineItemCard(
                        item: item,
                        isLast: index == items.count - 1,
                        onDocumentTap: onDocumentTap,
                        onDocumentInfo: onDocumentInfo
                    )
                }
            }
        }
    }
    
    private var dayOfMonth: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        return "\(day)"
    }
    
    private var monthAbbr: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).uppercased()
    }
}

// MARK: - Timeline Item Card

private struct TimelineItemCard: View {
    let item: TimelineItem
    let isLast: Bool
    let onDocumentTap: (MedicalDocument) -> Void
    let onDocumentInfo: (MedicalDocument) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline connector
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(hex: "2E3192"))
                    .frame(width: 10, height: 10)
                
                if !isLast {
                    Rectangle()
                        .fill(Color(hex: "2E3192").opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)
            .padding(.leading, 20)
            
            // Content Card
            VStack(alignment: .leading, spacing: 10) {
                switch item.type {
                case .document(let document):
                    documentCard(document)
                case .documents(let documents):
                    if let firstDoc = documents.first {
                        documentsGroupCard(firstDoc, count: documents.count)
                    }
                case .consultation(let doctor, let location, _):
                    consultationCard(doctor: doctor, location: location)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glass(cornerRadius: 16)
        }
    }
    
    @ViewBuilder
    private func documentCard(_ document: MedicalDocument) -> some View {
        Button {
            onDocumentTap(document)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                            HStack {
                    Text(document.folderName ?? document.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Button {
                        onDocumentInfo(document)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: categoryIcon(document.category))
                        .font(.system(size: 11))
                    Text(document.category)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(categoryColor(document.category))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(categoryColor(document.category).opacity(0.12))
                )
                
                if let doctor = item.doctorName, !doctor.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                        Text(doctor)
                            .font(.system(size: 12))
                    }
                                        .foregroundColor(.secondary)
                }
                
                if let location = item.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 10))
                        Text(location)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func documentsGroupCard(_ document: MedicalDocument, count: Int) -> some View {
        Button {
            onDocumentTap(document)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(document.folderName ?? document.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(count) files")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.12))
                        )
                    
                    Spacer()
                    
                    Button {
                        onDocumentInfo(document)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Image(systemName: categoryIcon(document.category))
                        .font(.system(size: 11))
                    Text(document.category)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(categoryColor(document.category))
                                    .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(categoryColor(document.category).opacity(0.12))
                )
            }
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func consultationCard(doctor: String?, location: String?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "1BBBCE").opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "stethoscope")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "1BBBCE"))
            }
            
                        VStack(alignment: .leading, spacing: 4) {
                Text("Consultation")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let doc = doctor, !doc.isEmpty {
                    Text(doc)
                        .font(.system(size: 13))
                                .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func categoryIcon(_ category: String) -> String {
        if let vaultCategory = VaultCategory.allCases.first(where: { $0.rawValue == category }) {
            return vaultCategory.icon
        }
        return "doc.fill"
    }
    
    private func categoryColor(_ category: String) -> Color {
        if let vaultCategory = VaultCategory.allCases.first(where: { $0.rawValue == category }) {
            return vaultCategory.color
        }
        return Color(hex: "2E3192")
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
                    .font(.system(size: 22, weight: .bold))
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
                                    .fill(Color(hex: "2E3192").opacity(0.15))
                                    .frame(width: 52, height: 52)
                                
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(hex: "2E3192"))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Browse Files")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("PDF, DOC, images and more")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
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
                                    .font(.system(size: 22))
                                    .foregroundColor(Color(hex: "1BBBCE"))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Photo Library")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Text("Select photos from your library")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
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
                                .font(.system(size: 20))
                                .foregroundColor(Color(hex: "2E3192"))
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(upload.fileName)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                
                                Text(upload.formattedSize)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation {
                                    viewModel.removePendingUpload(upload)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Selected Files (\(viewModel.pendingUploads.count))")
                        Spacer()
                        Text(totalSizeFormatted)
                            .font(.caption)
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
                                .tint(Color(hex: "2E3192"))
                            
                            Text("Uploading \(viewModel.currentUploadIndex + 1) of \(viewModel.totalUploadFiles)...")
                                .font(.caption)
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
                    .fontWeight(.semibold)
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
                                .font(.system(size: 18, weight: .semibold))
                                .multilineTextAlignment(.center)
                            
                            Text(document.category)
                                .font(.system(size: 14))
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
                            .font(.body)
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
                            .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "2E3192").opacity(0.1))
                                    .foregroundColor(Color(hex: "2E3192"))
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
                .font(.system(size: 40))
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
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
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

// MARK: - Folder Detail Sheet

private struct FolderDetailSheet: View {
    let folder: DocumentFolder
    @ObservedObject var viewModel: VaultViewModel
    let onViewDocument: (MedicalDocument) -> Void
    let onDocumentInfo: (MedicalDocument) -> Void
    let onDeleteDocument: (MedicalDocument) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private var folderColor: Color {
        let hash = abs(folder.id.hashValue)
        return hash % 2 == 0 ? Color(hex: "2E3192") : Color(hex: "1BBBCE")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Folder Header
                    folderHeader
                    
                    // Files Grid
                    filesGrid
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .navigationTitle(folder.folderTitle)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var folderHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundColor(folderColor)
            
            VStack(spacing: 8) {
                if let date = folder.documentDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(formatDate(date))
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let doctor = folder.doctorName, !doctor.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                        Text(doctor)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                if let location = folder.location, !location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.caption)
                        Text(location)
                            .font(.subheadline)
                    }
                    .foregroundColor(.secondary)
                }
                
                Text("\(folder.fileCount) files • \(folder.formattedTotalSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .glass(cornerRadius: 20)
    }
    
    private var filesGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(folder.documents) { document in
                FileGridItem(
                    document: document,
                    viewModel: viewModel,
                    onTap: { onViewDocument(document) },
                    onInfo: { onDocumentInfo(document) },
                    onDelete: { onDeleteDocument(document) }
                )
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - File Grid Item

private struct FileGridItem: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    let onTap: () -> Void
    let onInfo: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnailURL: URL?
    
    private var isImage: Bool {
        ["jpg", "jpeg", "png", "heic", "gif"].contains(document.fileType.lowercased())
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 80, height: 80)
                    
                    if isImage, let url = thumbnailURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            case .failure:
                                fileIcon
                            case .empty:
                                ProgressView()
                            @unknown default:
                                fileIcon
                            }
                        }
                    } else {
                        fileIcon
                    }
                }
                
                // File Name
                Text(document.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text(document.fileType.uppercased())
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onTap() } label: {
                Label("Open", systemImage: "eye")
            }
            Button { onInfo() } label: {
                Label("Info", systemImage: "info.circle")
            }
            Divider()
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .task(id: document.id) {
            if isImage {
                thumbnailURL = await viewModel.getDocumentURL(document)
            }
        }
    }
    
    private var fileIcon: some View {
        Image(systemName: document.icon)
            .font(.title2)
            .foregroundColor(document.iconColor.opacity(0.7))
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
