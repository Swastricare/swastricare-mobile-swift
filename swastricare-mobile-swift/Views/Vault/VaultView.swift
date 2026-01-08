//
//  VaultView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Medical Vault with URL-based file viewing
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

// MARK: - Pending Action

private enum PendingAction {
    case view(MedicalDocument)
    case info(MedicalDocument)
}

struct VaultView: View {
    
    // MARK: - ViewModel
    
    @StateObject private var viewModel = DependencyContainer.shared.vaultViewModel
    
    // MARK: - Local State
    
    @State private var showAddOptions = false
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedDocument: MedicalDocument?
    @State private var documentForDetails: MedicalDocument?
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: MedicalDocument?
    // Selection state moved to ViewModel
    @State private var selectedFolder: DocumentFolder?
    @State private var showErrorAlert = false
    @State private var pendingAction: PendingAction?
    
    // MARK: - Body
    
    var body: some View {
        baseView
            .modifier(SheetModifiers(
                showAddOptions: $showAddOptions,
                showDocumentPicker: $showDocumentPicker,
                showPhotoPicker: $showPhotoPicker,
                selectedPhotos: $selectedPhotos,
                selectedDocument: $selectedDocument,
                documentForDetails: $documentForDetails,
                selectedFolder: $selectedFolder,
                showDeleteConfirmation: $showDeleteConfirmation,
                showErrorAlert: $showErrorAlert,
                documentToDelete: $documentToDelete,
                pendingAction: $pendingAction,
                viewModel: viewModel,
                uploadSheet: { AnyView(uploadSheet) },
                onHandlePhotos: handleSelectedPhotos,
                onConfirmDelete: confirmDelete
            ))
    }
    
    private var baseView: some View {
        ZStack(alignment: .bottomTrailing) {
            mainContent
            
            if !viewModel.isSelectionMode {
                floatingAddButton
            }
        }
        .navigationTitle("Medical Vault")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchQuery, prompt: "Search documents...")
        .toolbar { toolbarContent }
        .task {
            await viewModel.loadDocuments()
        }
        .refreshable {
            await viewModel.loadDocuments()
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                categoryFilter
                
                if viewModel.isSelectionMode {
                    selectionBar
                }
                
                documentsSection
            }
            .padding(.bottom, 100) // Space for floating button
        }
    }
    
    // MARK: - Category Filter
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryPill(
                    title: "All",
                    count: viewModel.totalDocuments,
                    isSelected: viewModel.selectedCategory == nil,
                    color: .gray
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.setCategory(nil)
                    }
                }
                
                ForEach(VaultCategory.allCases) { category in
                    CategoryPill(
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
            .padding(.horizontal)
        }
    }
    
    // MARK: - Selection Bar
    
    private var selectionBar: some View {
        HStack {
            Text("\(viewModel.selectedDocuments.count) selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Select All") {
                viewModel.selectAllDocuments()
            }
            .font(.subheadline)
            
            Button(role: .destructive) {
                Task { await deleteSelectedDocuments() }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(viewModel.selectedDocuments.isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Material.bar)
    }
    
    // MARK: - Documents Section
    
    private var documentsSection: some View {
        Group {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                loadingView
            } else if viewModel.filteredDocuments.isEmpty {
                emptyState
            } else {
                switch viewModel.viewMode {
                case .folders:
                    foldersView
                case .timeline:
                    timelineView
                case .list:
                    documentsList
                }
            }
        }
        .transaction { transaction in
            transaction.animation = nil // Disable animations when switching views
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color(hex: "2E3192"))
            Text("Loading documents...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundStyle(Color(hex: "2E3192").opacity(0.3))
            
            VStack(spacing: 6) {
                Text("No Documents")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("Add your medical documents to get started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    private var documentsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(viewModel.filteredDocuments) { document in
                DocumentRowWithPreview(
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
                            viewDocument(document)
                        }
                    },
                    onInfo: {
                        documentForDetails = document
                    },
                    onDelete: { confirmDelete(document) }
                )
            }
        }
        .padding(.horizontal, 16)
        .transaction { transaction in
            transaction.animation = nil // Disable implicit animations for stable rendering
        }
    }
    
    // MARK: - Folders View (Grid like Files app)
    
    private var foldersView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 20) {
            ForEach(viewModel.groupedDocuments, id: \.id) { folder in
                FolderGridItem(
                    folder: folder,
                    onTap: {
                        selectedFolder = folder
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .transaction { transaction in
            transaction.animation = nil // Disable implicit animations for stable rendering
        }
    }
    
    // MARK: - Timeline View
    
    private var timelineView: some View {
        let grouped = groupTimelineItemsByDate(viewModel.timelineItems)
        
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(grouped.keys.sorted(by: >), id: \.self) { date in
                    TimelineDateSection(
                        date: date,
                        items: grouped[date] ?? [],
                        onDocumentTap: { document in
                            viewDocument(document)
                        },
                        onDocumentInfo: { document in
                            documentForDetails = document
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .transaction { transaction in
            transaction.animation = nil // Disable implicit animations for stable rendering
        }
    }
    
    private func groupTimelineItemsByDate(_ items: [TimelineItem]) -> [Date: [TimelineItem]] {
        let calendar = Calendar.current
        return Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.date)
        }
    }
    
    // MARK: - Floating Add Button
    
    private var floatingAddButton: some View {
        Button {
            showAddOptions = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, Color(hex: "2E3192"))
                .shadow(color: Color(hex: "2E3192").opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 28)
        .accessibilityLabel("Add document")
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                // View mode toggle
                Menu {
                    Button {
                        viewModel.setViewMode(.timeline)
                    } label: {
                        Label("Timeline", systemImage: "calendar")
                        if viewModel.viewMode == .timeline {
                            Image(systemName: "checkmark")
                        }
                    }
                    
                    Button {
                        viewModel.setViewMode(.folders)
                    } label: {
                        Label("Folders", systemImage: "folder.fill")
                        if viewModel.viewMode == .folders {
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
                }
                
                // More options menu
                Menu {
                    Button(action: { viewModel.toggleSelectionMode() }) {
                        Label(
                            viewModel.isSelectionMode ? "Done" : "Select",
                            systemImage: viewModel.isSelectionMode ? "checkmark.circle" : "checkmark.circle.fill"
                        )
                    }
                    
                    Divider()
                    
                    Menu("View Mode") {
                        Button {
                            viewModel.setViewMode(.timeline)
                        } label: {
                            Label("Timeline", systemImage: "calendar")
                            if viewModel.viewMode == .timeline {
                                Image(systemName: "checkmark")
                            }
                        }
                        
                        Button {
                            viewModel.setViewMode(.folders)
                        } label: {
                            Label("Folders", systemImage: "folder.fill")
                            if viewModel.viewMode == .folders {
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
                    }
                    
                    Menu("Sort By") {
                        Button("Upload Date (Newest)") { viewModel.setSortOrder(.dateDescending) }
                        Button("Upload Date (Oldest)") { viewModel.setSortOrder(.dateAscending) }
                        Divider()
                        Button("Timeline (Newest)") { viewModel.setSortOrder(.timelineDescending) }
                        Button("Timeline (Oldest)") { viewModel.setSortOrder(.timelineAscending) }
                        Divider()
                        Button("Name (A-Z)") { viewModel.setSortOrder(.nameAscending) }
                        Button("Size") { viewModel.setSortOrder(.sizeDescending) }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    
    // MARK: - Upload Sheet
    
    private var uploadSheet: some View {
        BatchUploadSheet(viewModel: viewModel)
    }
    
    // MARK: - Helper Functions
    
    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var files: [(String, Data)] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let fileName = "Photo_\(timestamp).jpg"
                files.append((fileName, data))
            }
        }
        
        if !files.isEmpty {
            viewModel.prepareMultipleUploads(files: files)
        }
        
        selectedPhotos = []
    }
    
    private var viewModeIcon: String {
        switch viewModel.viewMode {
        case .timeline: return "calendar"
        case .folders: return "folder.fill"
        case .list: return "list.bullet"
        }
    }
    
    private func viewDocument(_ document: MedicalDocument) {
        selectedDocument = document
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

// MARK: - Folder Grid Item (iOS Files app style)

private struct FolderGridItem: View {
    let folder: DocumentFolder
    let onTap: () -> Void
    
    // Cache color to prevent recalculation
    private var folderColor: Color {
        // Use app theme colors (royal blue or teal) - stable based on folder ID
        let stableHash = abs(folder.id.hashValue)
        return stableHash % 2 == 0 ? Color(hex: "2E3192") : Color(hex: "1BBBCE")
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Folder icon - iOS Files app style
                ZStack(alignment: .topTrailing) {
                    // Folder with shadow effect
                    ZStack {
                        // Shadow layer
                        Image(systemName: "folder.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(folderColor.opacity(0.25))
                            .offset(x: 1.5, y: 1.5)
                        
                        // Main folder
                        Image(systemName: "folder.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(folderColor)
                    }
                    
                    // File count badge - iOS Files style
                    if folder.fileCount > 0 {
                        Text("\(folder.fileCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(height: 20)
                            .padding(.horizontal, folder.fileCount > 9 ? 5 : 4)
                            .frame(minWidth: 20)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.75))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                            .offset(x: 6, y: -6)
                    }
                }
                .frame(height: 72)
                .shadow(color: folderColor.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Folder name - iOS Files app typography
                VStack(spacing: 2) {
                    Text(folder.folderTitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 30)
                    
                    Text(folder.shortSubtitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Folder Detail View (Opens when tapping folder)

private struct FolderDetailView: View {
    let folder: DocumentFolder
    @ObservedObject var viewModel: VaultViewModel
    let onViewDocument: (MedicalDocument) -> Void
    let onDocumentInfo: (MedicalDocument) -> Void
    let onDeleteDocument: (MedicalDocument) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let fileGridColumns = [
        GridItem(.adaptive(minimum: 90, maximum: 110), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Folder Info Header
                    folderHeader
                    
                    // Files Grid
                    LazyVGrid(columns: fileGridColumns, spacing: 16) {
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
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle(folder.folderTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private var folderHeader: some View {
        VStack(spacing: 16) {
            // Folder icon - clean
            Image(systemName: "folder.fill")
                .font(.system(size: 56))
                .foregroundStyle(folderColor)
            
            // Details - minimal and clean
            VStack(spacing: 8) {
                if let date = folder.documentDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDate(date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let doctor = folder.doctorName, !doctor.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(doctor)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let location = folder.location, !location.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\(folder.fileCount) items • \(folder.formattedTotalSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            
            // Tags - cleaner design
            if let tags = folder.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.08))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
    }
    
    private var folderColor: Color {
        // Use app theme colors (royal blue or teal)
        // Alternate based on folder ID for visual variety
        let hash = folder.id.hashValue
        return hash % 2 == 0 ? Color(hex: "2E3192") : Color(hex: "1BBBCE")
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - File Grid Item (inside folder detail)

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
                // File thumbnail/icon - clean
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .frame(width: 76, height: 76)
                    
                    if isImage, let url = thumbnailURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 76, height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            case .failure(_):
                                Image(systemName: document.icon)
                                    .font(.title2)
                                    .foregroundColor(document.iconColor.opacity(0.6))
                            case .empty:
                                ProgressView()
                                    .frame(width: 76, height: 76)
                            @unknown default:
                                Image(systemName: document.icon)
                                    .font(.title2)
                                    .foregroundColor(document.iconColor.opacity(0.6))
                            }
                        }
                    } else {
                        Image(systemName: document.icon)
                            .font(.title2)
                            .foregroundColor(document.iconColor.opacity(0.6))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // Info button - minimal
                    Button(action: onInfo) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white, Color.gray.opacity(0.7))
                    }
                    .offset(x: 2, y: -2)
                }
                
                // File name - clean typography
                Text(document.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                // File type - subtle
                Text(document.fileType.uppercased())
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
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
                Label("Info", systemImage: "info.circle")
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
}

// MARK: - Document Row with Preview

private struct DocumentRowWithPreview: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onInfo: () -> Void
    let onDelete: () -> Void
    
    @State private var thumbnailURL: URL?
    @State private var isLoadingThumbnail = false
    
    var isImage: Bool {
        let imageTypes = ["jpg", "jpeg", "png", "heic", "gif"]
        return imageTypes.contains(document.fileType.lowercased())
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Selection or Thumbnail
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundColor(isSelected ? Color(hex: "2E3192") : .secondary)
                        .frame(width: 24)
                } else {
                    thumbnailView
                }
                
                // Document info - clean and organized
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(document.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Metadata row
                    HStack(spacing: 6) {
                        // Category badge
                        Text(document.category)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                        
                        // Date and size
                        if let documentDate = document.documentDate {
                            Text(formatDate(documentDate))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        } else {
                            Text(document.formattedDate)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Text(document.formattedFileSize)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Additional info (doctor, location) - compact
                    if let doctorName = document.doctorName, !doctorName.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(doctorName)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    if let location = document.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(location)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Tags and badges - compact
                    HStack(spacing: 6) {
                        // Tags
                        if let tags = document.tags, !tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(tags.prefix(2), id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 10))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.08))
                                        .cornerRadius(4)
                                }
                                if tags.count > 2 {
                                    Text("+\(tags.count - 2)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Reminder badge
                        if document.reminderDate != nil {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                        }
                        
                        // Appointment badge
                        if document.appointmentDate != nil {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 10))
                                .foregroundColor(.purple)
                        }
                    }
                }
                
                Spacer()
                
                // Info button - minimal
                if !isSelectionMode {
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "2E3192") : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .task {
            if isImage && thumbnailURL == nil {
                await loadThumbnail()
            }
        }
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if isImage {
            // Show image thumbnail
            if let url = thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        filePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(width: 52, height: 52)
                    @unknown default:
                        filePlaceholder
                    }
                }
            } else if isLoadingThumbnail {
                ProgressView()
                    .frame(width: 52, height: 52)
            } else {
                filePlaceholder
            }
        } else {
            filePlaceholder
        }
    }
    
    private var filePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(document.iconColor.opacity(0.1))
                .frame(width: 52, height: 52)
            
            Image(systemName: document.icon)
                .font(.system(size: 20))
                .foregroundColor(document.iconColor.opacity(0.7))
        }
    }
    
    private func loadThumbnail() async {
        isLoadingThumbnail = true
        thumbnailURL = await viewModel.getDocumentURL(document)
        isLoadingThumbnail = false
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

private struct CategoryPill: View {
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
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
                Text("(\(count))")
                    .font(.caption2)
                    .opacity(0.7)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.gray.opacity(0.15))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

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
                        
                        VStack(spacing: 4) {
                            Text(document.title)
                                .font(.headline)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            Text(document.category)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                // Timeline & Important Dates
                if document.documentDate != nil || document.reminderDate != nil || document.appointmentDate != nil {
                    Section("Timeline") {
                        if let documentDate = document.documentDate {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Document Date")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDate(documentDate))
                                        .font(.subheadline)
                                }
                            }
                        }
                        
                        if let reminderDate = document.reminderDate {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Reminder")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDateTime(reminderDate))
                                        .font(.subheadline)
                                }
                            }
                        }
                        
                        if let appointmentDate = document.appointmentDate {
                            HStack {
                                Image(systemName: "calendar.badge.clock")
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Appointment")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDateTime(appointmentDate))
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                }
                
                // Description
                if let description = document.description, !description.isEmpty {
                    Section("Description") {
                        Text(description)
                            .font(.body)
                    }
                }
                
                // Doctor & Location
                if document.doctorName != nil || document.location != nil {
                    Section("Provider Information") {
                        if let doctorName = document.doctorName, !doctorName.isEmpty {
                            LabeledContent("Doctor/Provider", value: doctorName)
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
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
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
                    
                    if let notes = document.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(notes)
                        }
                    }
                }
                
                // Actions Section
                Section {
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onView()
                        }
                    }) {
                        Label("View Document", systemImage: "eye.fill")
                    }
                    
                    Button(action: {
                        showEditSheet = true
                    }) {
                        Label("Edit Metadata", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDelete()
                        }
                    }) {
                        Label("Delete Document", systemImage: "trash.fill")
                    }
                }
            }
            .navigationTitle("Document Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditDocumentMetadataSheet(document: document, viewModel: viewModel)
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
                        .frame(maxHeight: 200)
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
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Add Document Sheet

private struct AddDocumentSheet: View {
    let onChooseFiles: () -> Void
    let onPhotoLibrary: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Choose Files Option
                Button(action: onChooseFiles) {
                    HStack(spacing: 16) {
                        Image(systemName: "folder.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 50, height: 50)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Choose Files")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Browse documents from your device")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Material.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
                
                // Photo Library Option
                Button(action: onPhotoLibrary) {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                            .frame(width: 50, height: 50)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Photo Library")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("Select photos from your library")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Material.ultraThinMaterial)
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Batch Upload Sheet (Single Metadata for All Files)

private struct BatchUploadSheet: View {
    @ObservedObject var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Shared metadata for all files
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
                // Selected Files Section - cleaner
                Section {
                    ForEach(viewModel.pendingUploads, id: \.fileName) { upload in
                        HStack(spacing: 12) {
                            // File icon - minimal
                            Image(systemName: upload.icon)
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 32)
                            
                            // File info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(upload.fileName)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                
                                Text(upload.formattedSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Remove button - subtle
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    viewModel.removePendingUpload(upload)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary.opacity(0.5))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    HStack {
                        Text("Files (\(viewModel.pendingUploads.count))")
                        Spacer()
                        Text(totalSizeFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Folder Name Section
                Section {
                    TextField("e.g., Annual Checkup, Lab Visit", text: $folderName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Folder/Visit Name")
                } footer: {
                    Text("This name will be used to group these documents together")
                }
                
                // Category Section
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(VaultCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Details Section
                Section("Details") {
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    
                    DatePicker("Document Date", selection: $documentDate, displayedComponents: .date)
                }
                
                // Provider Section
                Section("Provider Information") {
                    TextField("Doctor/Provider Name", text: $doctorName)
                    TextField("Hospital/Clinic Location", text: $location)
                }
                
                // Reminders Section
                Section("Reminders & Appointments") {
                    Toggle("Set Reminder", isOn: $hasReminder)
                    
                    if hasReminder {
                        DatePicker("Reminder Date", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Toggle("Set Appointment", isOn: $hasAppointment)
                    
                    if hasAppointment {
                        DatePicker("Appointment Date", selection: $appointmentDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                // Tags Section
                Section {
                    TextField("Tags (comma separated)", text: $tags)
                } header: {
                    Text("Tags")
                } footer: {
                    Text("e.g., urgent, follow-up, checkup")
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
        // Create shared metadata
        let tagArray = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let sharedMetadata = DocumentMetadata(
            name: "", // Will use individual file names
            folderName: folderName.isEmpty ? nil : folderName,
            description: description.isEmpty ? nil : description,
            documentDate: documentDate,
            reminderDate: hasReminder ? reminderDate : nil,
            appointmentDate: hasAppointment ? appointmentDate : nil,
            doctorName: doctorName.isEmpty ? nil : doctorName,
            location: location.isEmpty ? nil : location,
            tags: tagArray
        )
        
        // Apply shared metadata to all pending uploads
        viewModel.applySharedMetadata(sharedMetadata, category: category)
        
        // Upload all
        await viewModel.uploadAllDocuments()
    }
}

// MARK: - Document Metadata Form (Legacy - kept for reference)

private struct DocumentMetadataForm: View {
    let upload: PendingUpload
    @ObservedObject var viewModel: VaultViewModel
    let onRemove: () -> Void
    
    @State private var name: String
    @State private var description: String
    @State private var documentDate: Date?
    @State private var reminderDate: Date?
    @State private var appointmentDate: Date?
    @State private var doctorName: String
    @State private var location: String
    @State private var tags: String
    @State private var category: VaultCategory
    @State private var isExpanded = false
    
    init(upload: PendingUpload, viewModel: VaultViewModel, onRemove: @escaping () -> Void) {
        self.upload = upload
        self.viewModel = viewModel
        self.onRemove = onRemove
        
        _name = State(initialValue: upload.metadata.name)
        _description = State(initialValue: upload.metadata.description ?? "")
        _documentDate = State(initialValue: upload.metadata.documentDate)
        _reminderDate = State(initialValue: upload.metadata.reminderDate)
        _appointmentDate = State(initialValue: upload.metadata.appointmentDate)
        _doctorName = State(initialValue: upload.metadata.doctorName ?? "")
        _location = State(initialValue: upload.metadata.location ?? "")
        _tags = State(initialValue: upload.metadata.tags.joined(separator: ", "))
        _category = State(initialValue: upload.category)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: upload.icon)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(upload.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(upload.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
                
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            
            if isExpanded {
                VStack(spacing: 16) {
                    // Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Document Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { _, newValue in
                                updateMetadata()
                            }
                    }
                    
                    // Category
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Category", selection: $category) {
                            ForEach(VaultCategory.allCases) { cat in
                                Label(cat.rawValue, systemImage: cat.icon)
                                    .tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: category) { _, _ in
                            updateMetadata()
                        }
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Add description (optional)", text: $description, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                            .onChange(of: description) { _, newValue in
                                updateMetadata()
                            }
                    }
                    
                    // Document Date
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Document Date")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("", selection: Binding(
                            get: { documentDate ?? Date() },
                            set: { documentDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .onChange(of: documentDate) { _, _ in
                            updateMetadata()
                        }
                    }
                    
                    // Doctor Name
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Doctor/Provider Name")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter doctor name (optional)", text: $doctorName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: doctorName) { _, newValue in
                                updateMetadata()
                            }
                    }
                    
                    // Location
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location/Clinic")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Enter location (optional)", text: $location)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: location) { _, newValue in
                                updateMetadata()
                            }
                    }
                    
                    // Reminder Date
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: Binding(
                            get: { reminderDate != nil },
                            set: { reminderDate = $0 ? Date() : nil }
                        )) {
                            Text("Set Reminder")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if reminderDate != nil {
                            DatePicker("", selection: Binding(
                                get: { reminderDate ?? Date() },
                                set: { reminderDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .onChange(of: reminderDate) { _, _ in
                                updateMetadata()
                            }
                        }
                    }
                    
                    // Appointment Date
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(isOn: Binding(
                            get: { appointmentDate != nil },
                            set: { appointmentDate = $0 ? Date() : nil }
                        )) {
                            Text("Set Appointment")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if appointmentDate != nil {
                            DatePicker("", selection: Binding(
                                get: { appointmentDate ?? Date() },
                                set: { appointmentDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .onChange(of: appointmentDate) { _, _ in
                                updateMetadata()
                            }
                        }
                    }
                    
                    // Tags
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tags (comma separated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("e.g., urgent, follow-up", text: $tags)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: tags) { _, newValue in
                                updateMetadata()
                            }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Material.ultraThinMaterial)
        )
    }
    
    private func updateMetadata() {
        let tagArray = tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let metadata = DocumentMetadata(
            name: name.isEmpty ? upload.fileName : name,
            description: description.isEmpty ? nil : description,
            documentDate: documentDate,
            reminderDate: reminderDate,
            appointmentDate: appointmentDate,
            doctorName: doctorName.isEmpty ? nil : doctorName,
            location: location.isEmpty ? nil : location,
            tags: tagArray
        )
        
        // Update the upload in viewModel
        if let index = viewModel.pendingUploads.firstIndex(where: { $0.fileName == upload.fileName }) {
            viewModel.pendingUploads[index].metadata = metadata
            viewModel.pendingUploads[index].category = category
        }
    }
}

// MARK: - Flow Layout (for tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
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

// MARK: - Edit Document Metadata Sheet

private struct EditDocumentMetadataSheet: View {
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
                        DatePicker("Reminder Date", selection: Binding(
                            get: { reminderDate ?? Date() },
                            set: { reminderDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                    
                    Toggle("Set Appointment", isOn: Binding(
                        get: { appointmentDate != nil },
                        set: { appointmentDate = $0 ? Date() : nil }
                    ))
                    
                    if appointmentDate != nil {
                        DatePicker("Appointment Date", selection: Binding(
                            get: { appointmentDate ?? Date() },
                            set: { appointmentDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                    }
                }
                
                Section("Provider Information") {
                    TextField("Doctor/Provider Name", text: $doctorName)
                    TextField("Location/Clinic", text: $location)
                }
                
                Section("Tags") {
                    TextField("Tags (comma separated)", text: $tags)
                }
            }
            .navigationTitle("Edit Metadata")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveMetadata() }
                    }
                    .disabled(isSaving || name.isEmpty)
                }
            }
        }
    }
    
    private func saveMetadata() async {
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
            await viewModel.loadDocuments()
            dismiss()
        } catch {
            // Handle error
            print("Failed to update: \(error)")
        }
        
        isSaving = false
    }
}

// MARK: - Multi Document Picker

private struct MultiDocumentPickerView: UIViewControllerRepresentable {
    let onPick: ([(String, Data)]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Support all common document types
        let contentTypes: [UTType] = [
            .pdf,
            .image,
            .jpeg,
            .png,
            .heic,
            .gif,
            .tiff,
            .bmp,
            .text,
            .plainText,
            .rtf,
            .data,
            .item,
            .content
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
            var errors: [String] = []
            
            for url in urls {
                let shouldAccess = url.startAccessingSecurityScopedResource()
                defer { if shouldAccess { url.stopAccessingSecurityScopedResource() } }
                
                do {
                    let data = try Data(contentsOf: url)
                    guard !data.isEmpty else {
                        errors.append("\(url.lastPathComponent) is empty")
                        continue
                    }
                    files.append((url.lastPathComponent, data))
                    print("✅ Loaded file: \(url.lastPathComponent) (\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)))")
                } catch {
                    let errorMsg = "Failed to read \(url.lastPathComponent): \(error.localizedDescription)"
                    errors.append(errorMsg)
                    print("❌ \(errorMsg)")
                }
            }
            
            if !files.isEmpty {
                onPick(files)
                if !errors.isEmpty {
                    print("⚠️ Some files could not be loaded: \(errors.joined(separator: ", "))")
                }
            } else if !errors.isEmpty {
                print("❌ No files could be loaded. Errors: \(errors.joined(separator: ", "))")
            }
        }
    }
}

// MARK: - Sheet Modifiers

private struct SheetModifiers: ViewModifier {
    @Binding var showAddOptions: Bool
    @Binding var showDocumentPicker: Bool
    @Binding var showPhotoPicker: Bool
    @Binding var selectedPhotos: [PhotosPickerItem]
    @Binding var selectedDocument: MedicalDocument?
    @Binding var documentForDetails: MedicalDocument?
    @Binding var selectedFolder: DocumentFolder?
    @Binding var showDeleteConfirmation: Bool
    @Binding var showErrorAlert: Bool
    @Binding var documentToDelete: MedicalDocument?
    @Binding var pendingAction: PendingAction?
    
    @ObservedObject var viewModel: VaultViewModel
    
    let uploadSheet: () -> AnyView
    let onHandlePhotos: ([PhotosPickerItem]) async -> Void
    let onConfirmDelete: (MedicalDocument) -> Void
    
    func body(content: Content) -> some View {
        content
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
                .presentationDetents([.height(280)])
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
                Task { await onHandlePhotos(newValue) }
            }
            .sheet(isPresented: $viewModel.showUploadSheet) {
                uploadSheet()
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
                    onDelete: { onConfirmDelete(document) }
                )
            }
            .sheet(item: $selectedFolder) { folder in
                FolderDetailView(
                    folder: folder,
                    viewModel: viewModel,
                    onViewDocument: { doc in
                        pendingAction = .view(doc)
                        selectedFolder = nil
                    },
                    onDocumentInfo: { doc in
                        pendingAction = .info(doc)
                        selectedFolder = nil
                    },
                    onDeleteDocument: { doc in
                        selectedFolder = nil
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 400_000_000)
                            onConfirmDelete(doc)
                        }
                    }
                )
            }
            .onChange(of: selectedFolder) { oldValue, newValue in
                if oldValue != nil && newValue == nil, let action = pendingAction {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        switch action {
                        case .view(let doc):
                            selectedDocument = doc
                        case .info(let doc):
                            documentForDetails = doc
                        }
                        pendingAction = nil
                    }
                }
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
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") {
                    viewModel.clearError()
                    showErrorAlert = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.errorMessage) { _, newValue in
                showErrorAlert = newValue != nil
            }
    }
}

// MARK: - Timeline Components

private struct TimelineDateSection: View {
    let date: Date
    let items: [TimelineItem]
    let onDocumentTap: (MedicalDocument) -> Void
    let onDocumentInfo: (MedicalDocument) -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }
    
    private var relativeDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date Header
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text(dayOfMonth)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "2E3192"))
                    
                    Text(monthAbbr)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(relativeDateFormatter.string(from: date))
                        .font(.system(size: 16, weight: .semibold))
                    
                    if Calendar.current.isDateInToday(date) {
                        Text("Today")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    } else if Calendar.current.isDateInYesterday(date) {
                        Text("Yesterday")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, 8)
            
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
        .padding(.bottom, 32)
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

private struct TimelineItemCard: View {
    let item: TimelineItem
    let isLast: Bool
    let onDocumentTap: (MedicalDocument) -> Void
    let onDocumentInfo: (MedicalDocument) -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline Line & Dot
            VStack(spacing: 0) {
                Circle()
                    .fill(itemColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    )
                
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            
            // Content Card - Complete card design
            VStack(alignment: .leading, spacing: 0) {
                // Card Content
                Group {
                    switch item.type {
                    case .document(let document):
                        DocumentTimelineCard(
                            document: document,
                            documents: nil,
                            doctorName: item.doctorName,
                            location: item.location,
                            folderName: item.folderName,
                            time: timeFormatter.string(from: item.date),
                            onTap: { onDocumentTap(document) },
                            onInfo: { onDocumentInfo(document) }
                        )
                    case .documents(let documents):
                        DocumentTimelineCard(
                            document: documents.first!,
                            documents: documents,
                            doctorName: item.doctorName,
                            location: item.location,
                            folderName: item.folderName,
                            time: timeFormatter.string(from: item.date),
                            onTap: {
                                // Open first document (for multiple files, user can use folders view)
                                onDocumentTap(documents.first!)
                            },
                            onInfo: { onDocumentInfo(documents.first!) }
                        )
                    case .consultation(let doctorName, let location, _):
                        ConsultationTimelineCard(
                            doctorName: doctorName,
                            location: location,
                            time: timeFormatter.string(from: item.date)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var itemColor: Color {
        switch item.type {
        case .document, .documents:
            return Color(hex: "2E3192")
        case .consultation:
            return Color(hex: "1BBBCE")
        }
    }
}

private struct DocumentTimelineCard: View {
    let document: MedicalDocument
    let documents: [MedicalDocument]? // Multiple documents if grouped
    let doctorName: String?
    let location: String?
    let folderName: String?
    let time: String
    let onTap: () -> Void
    let onInfo: () -> Void
    
    private var fileCount: Int {
        documents?.count ?? 1
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with time and info button
                HStack {
                    // Time badge
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(time)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
                    
                    Spacer()
                    
                    Button(action: onInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Document Info
                VStack(alignment: .leading, spacing: 8) {
                    // Name (only folderName, no filename) with file count if multiple
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if let name = document.folderName, !name.isEmpty {
                            Text(name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        } else {
                            Text(document.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                        
                        // Show file count badge if multiple files
                        if fileCount > 1 {
                            Text("\(fileCount) files")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                    }
                    
                    // Category with icon
                    HStack(spacing: 6) {
                        Image(systemName: categoryIcon(for: document.category))
                            .font(.system(size: 12))
                        Text(document.category)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(categoryColor(for: document.category))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(categoryColor(for: document.category).opacity(0.1))
                    )
                }
                
                // Description
                if let description = document.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // Metadata: Doctor and Hospital
                if doctorName != nil || location != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        if let doctor = doctorName, !doctor.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(doctor)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let loc = location, !loc.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text(loc)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .glass(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
    
    private func categoryIcon(for category: String) -> String {
        if let vaultCategory = VaultCategory.allCases.first(where: { $0.rawValue == category }) {
            return vaultCategory.icon
        }
        // Default icon if category doesn't match
        return "doc.fill"
    }
    
    private func categoryColor(for category: String) -> Color {
        if let vaultCategory = VaultCategory.allCases.first(where: { $0.rawValue == category }) {
            return vaultCategory.color
        }
        // Default color
        return Color(hex: "2E3192")
    }
}

private struct ConsultationTimelineCard: View {
    let doctorName: String?
    let location: String?
    let time: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with time
            HStack {
                // Time badge
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text(time)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "1BBBCE"))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "1BBBCE").opacity(0.1))
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Consultation")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let doctor = doctorName, !doctor.isEmpty {
                        Text(doctor)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            if let loc = location, !loc.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(loc)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .glass(cornerRadius: 16)
    }
}

#Preview {
    NavigationStack {
        VaultView()
    }
}
