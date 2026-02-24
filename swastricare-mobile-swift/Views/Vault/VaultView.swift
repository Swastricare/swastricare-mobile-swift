//
//  VaultView.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - Views Layer
//  Medical Vault with Movements+ UI design
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

// MARK: - Vault Design Colors

struct VaultColors {
    static let primary = Color(hex: "C6FF00") // Lime green
    static let secondary = Color(hex: "4ECDC4") // Teal
    static let accent = Color(hex: "45B7D1") // Blue
    static let purple = Color(hex: "AF52DE")
    static let coral = Color(hex: "FF6B6B")
    static let darkCard = Color(hex: "1C1C1E")
    static let darkCardSecondary = Color(hex: "2C2C2E")
    
    static func card(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkCardSecondary : Color(UIColor.secondarySystemBackground)
    }
    
    static func background(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemBackground)
    }
}

// MARK: - Main Vault View

struct VaultView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var viewModel = DependencyContainer.shared.vaultViewModel
    
    @State private var showAddOptions = false
    @State private var showDocumentPicker = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedDocument: MedicalDocument?
    @State private var documentForDetails: MedicalDocument?
    @State private var showDeleteConfirmation = false
    @State private var documentToDelete: MedicalDocument?
    @State private var selectedFolder: DocumentFolder?
    @State private var hasAppeared = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VaultColors.background(for: colorScheme)
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.top, 8)
                        
                        storageOverviewSection
                            .padding(.top, 24)
                        
                        searchSection
                            .padding(.top, 20)
                        
                        categoryChipsSection
                            .padding(.top, 16)
                        
                        quickActionsSection
                            .padding(.top, 24)
                        
                        contentSection
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 20)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 100 + geo.safeAreaInsets.bottom)
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
        }
        .onAppear {
            AppAnalyticsService.shared.logScreen("Vault")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
        .refreshable {
            await viewModel.loadDocuments(forceRefresh: true)
        }
        .sheet(isPresented: $showAddOptions) {
            VaultAddDocumentSheet(
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
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDocumentPicker) {
            VaultDocumentPickerView { files in
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
            VaultBatchUploadSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedDocument) { document in
            DocumentViewer(document: document)
        }
        .sheet(item: $documentForDetails) { document in
            VaultDocumentDetailSheet(
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
            VaultFolderDetailSheet(
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
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Medical Vault")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Your secure health records")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // View Mode Toggle
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
                
                Divider()
                
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.toggleSelectionMode()
                    }
                } label: {
                    Label(viewModel.isSelectionMode ? "Cancel Selection" : "Select", systemImage: "checkmark.circle")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(VaultColors.card(for: colorScheme))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: viewModeIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : -20)
    }
    
    private var viewModeIcon: String {
        switch viewModel.viewMode {
        case .folders: return "folder.fill"
        case .timeline: return "calendar"
        case .list: return "list.bullet"
        }
    }
    
    // MARK: - Storage Overview Section
    
    private var storageOverviewSection: some View {
        HStack(spacing: 16) {
            // Documents Count Card
            VaultStatCard(
                title: "Documents",
                value: "\(viewModel.totalDocuments)",
                icon: "doc.fill",
                color: VaultColors.primary
            )
            
            // Storage Used Card
            VaultStatCard(
                title: "Storage",
                value: viewModel.totalStorageFormatted,
                icon: "externaldrive.fill",
                color: VaultColors.secondary
            )
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: hasAppeared)
    }
    
    // MARK: - Search Section
    
    private var searchSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            TextField("Search documents...", text: $viewModel.searchQuery)
                .font(.system(size: 16))
            
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(VaultColors.card(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VaultColors.primary.opacity(0.3), lineWidth: 1)
        )
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: hasAppeared)
    }
    
    // MARK: - Category Chips Section
    
    private var categoryChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                VaultCategoryChip(
                    title: "All",
                    count: viewModel.totalDocuments,
                    isSelected: viewModel.selectedCategory == nil,
                    color: VaultColors.primary
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.setCategory(nil)
                    }
                }
                
                ForEach(VaultCategory.allCases) { category in
                    VaultCategoryChip(
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
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.25), value: hasAppeared)
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    VaultQuickActionCard(
                        title: "Upload",
                        subtitle: "Add new files",
                        icon: "arrow.up.doc.fill",
                        backgroundColor: VaultColors.primary,
                        contentColor: .black
                    ) {
                        showAddOptions = true
                    }
                    
                    VaultQuickActionCard(
                        title: "Scan",
                        subtitle: "Scan document",
                        icon: "doc.text.viewfinder",
                        backgroundColor: VaultColors.secondary,
                        contentColor: .white
                    ) {
                        showAddOptions = true
                    }
                    
                    VaultQuickActionCard(
                        title: "Photos",
                        subtitle: "From gallery",
                        icon: "photo.on.rectangle",
                        backgroundColor: VaultColors.accent,
                        contentColor: .white
                    ) {
                        showPhotoPicker = true
                    }
                }
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: hasAppeared)
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        Group {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                vaultLoadingView
            } else if let error = viewModel.errorMessage, viewModel.documents.isEmpty {
                vaultErrorView(error)
            } else if viewModel.filteredDocuments.isEmpty {
                vaultEmptyStateView
            } else {
                documentsContentView
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.35), value: hasAppeared)
    }
    
    // MARK: - Documents Content View
    
    private var documentsContentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(viewModel.viewMode == .folders ? "Folders" : (viewModel.viewMode == .timeline ? "Timeline" : "All Documents"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if viewModel.isSelectionMode {
                    selectionBar
                }
            }
            
            switch viewModel.viewMode {
            case .folders:
                foldersGridView
            case .timeline:
                timelineView
            case .list:
                documentListView
            }
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
                VaultFolderCard(folder: folder, colorScheme: colorScheme) {
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
                VaultTimelineDateSection(
                    date: date,
                    items: grouped[date] ?? [],
                    colorScheme: colorScheme,
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
                VaultDocumentCard(
                    document: document,
                    viewModel: viewModel,
                    colorScheme: colorScheme,
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
    
    // MARK: - Selection Bar
    
    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("\(viewModel.selectedDocuments.count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(VaultColors.primary))
            
            Button {
                viewModel.selectAllDocuments()
            } label: {
                Text("All")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VaultColors.primary)
            }
            
            Button(role: .destructive) {
                Task { await deleteSelectedDocuments() }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            }
            .disabled(viewModel.selectedDocuments.isEmpty)
            .opacity(viewModel.selectedDocuments.isEmpty ? 0.5 : 1)
        }
    }
    
    // MARK: - Loading View
    
    private var vaultLoadingView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(VaultColors.primary.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(VaultColors.primary)
            }
            
            VStack(spacing: 8) {
                Text("Loading Documents")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Please wait...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Error View
    
    private func vaultErrorView(_ error: String) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(VaultColors.coral.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(VaultColors.coral)
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
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(VaultColors.primary)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Empty State View
    
    private var vaultEmptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(VaultColors.primary.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(VaultColors.primary)
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
            
            Button {
                showAddOptions = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add Your First Document")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(VaultColors.primary)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
    
    // MARK: - Floating Add Button
    
    private var floatingAddButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showAddOptions = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Add")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(VaultColors.primary)
                    .shadow(color: VaultColors.primary.opacity(0.4), radius: 12, x: 0, y: 6)
            )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100)
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

// MARK: - Vault Stat Card

private struct VaultStatCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(VaultColors.card(for: colorScheme))
        )
    }
}

// MARK: - Vault Category Chip

private struct VaultCategoryChip: View {
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
                    .font(.system(size: 14, weight: .semibold))
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.black.opacity(0.2) : Color.secondary.opacity(0.15))
                    )
            }
            .foregroundColor(isSelected ? .black : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? color : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Vault Quick Action Card

private struct VaultQuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let backgroundColor: Color
    let contentColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(contentColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(contentColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(contentColor)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(contentColor.opacity(0.7))
                }
            }
            .padding(16)
            .frame(width: 130, height: 130)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Vault Folder Card

private struct VaultFolderCard: View {
    let folder: DocumentFolder
    let colorScheme: ColorScheme
    let onTap: () -> Void
    
    private var folderColor: Color {
        let stableHash = abs(folder.id.hashValue)
        let colors: [Color] = [VaultColors.primary, VaultColors.secondary, VaultColors.accent, VaultColors.purple]
        return colors[stableHash % colors.count]
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(folderColor.opacity(0.3))
                            .offset(x: 2, y: 2)
                        
                        Image(systemName: "folder.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(folderColor)
                    }
                    
                    if folder.fileCount > 0 {
                        Text("\(folder.fileCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(
                                Circle()
                                    .fill(VaultColors.primary)
                            )
                            .offset(x: 8, y: -4)
                    }
                }
                
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
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(VaultColors.card(for: colorScheme))
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Vault Document Card

private struct VaultDocumentCard: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    let colorScheme: ColorScheme
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
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? VaultColors.primary : .secondary)
                        .frame(width: 44, height: 44)
                } else {
                    thumbnailView
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(document.category)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(categoryColor(document.category))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(categoryColor(document.category).opacity(0.15))
                            )
                        
                        if let docDate = document.documentDate {
                            Text(formatDate(docDate))
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(VaultColors.card(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? VaultColors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onTap() } label: { Label("Open", systemImage: "eye") }
            Button { onInfo() } label: { Label("Details", systemImage: "info.circle") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
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
        return VaultColors.primary
    }
}

// MARK: - Vault Timeline Date Section

private struct VaultTimelineDateSection: View {
    let date: Date
    let items: [TimelineItem]
    let colorScheme: ColorScheme
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text(dayOfMonth)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(VaultColors.primary)
                    
                    Text(monthAbbr)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VaultColors.card(for: colorScheme))
                )
                
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
            
            VStack(spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    VaultTimelineItemCard(
                        item: item,
                        isLast: index == items.count - 1,
                        colorScheme: colorScheme,
                        onDocumentTap: onDocumentTap,
                        onDocumentInfo: onDocumentInfo
                    )
                }
            }
        }
    }
}

// MARK: - Vault Timeline Item Card

private struct VaultTimelineItemCard: View {
    let item: TimelineItem
    let isLast: Bool
    let colorScheme: ColorScheme
    let onDocumentTap: (MedicalDocument) -> Void
    let onDocumentInfo: (MedicalDocument) -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Circle()
                    .fill(VaultColors.primary)
                    .frame(width: 10, height: 10)
                
                if !isLast {
                    Rectangle()
                        .fill(VaultColors.primary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)
            .padding(.leading, 20)
            
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
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(VaultColors.card(for: colorScheme))
            )
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
                    .fill(VaultColors.secondary.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "stethoscope")
                    .font(.system(size: 20))
                    .foregroundColor(VaultColors.secondary)
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
        return VaultColors.primary
    }
}

// MARK: - Vault Add Document Sheet

private struct VaultAddDocumentSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let onChooseFiles: () -> Void
    let onPhotoLibrary: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Add Documents")
                    .font(.system(size: 24, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                
                Text("Choose how you want to add your documents")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                
                VStack(spacing: 12) {
                    Button {
                        dismiss()
                        onChooseFiles()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(VaultColors.primary.opacity(0.2))
                                    .frame(width: 52, height: 52)
                                
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(VaultColors.primary)
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
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(VaultColors.card(for: colorScheme))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    
                    Button {
                        dismiss()
                        onPhotoLibrary()
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(VaultColors.secondary.opacity(0.2))
                                    .frame(width: 52, height: 52)
                                
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 22))
                                    .foregroundColor(VaultColors.secondary)
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
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(VaultColors.card(for: colorScheme))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .padding(.horizontal, 20)
                
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Vault Batch Upload Sheet

private struct VaultBatchUploadSheet: View {
    @ObservedObject var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
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
                Section {
                    ForEach(viewModel.pendingUploads, id: \.fileName) { upload in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(VaultColors.primary.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: upload.icon)
                                    .font(.system(size: 16))
                                    .foregroundColor(VaultColors.primary)
                            }
                            
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
                
                Section {
                    TextField("e.g., Annual Checkup, Lab Results", text: $folderName)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Folder Name")
                } footer: {
                    Text("Group these documents under a common name")
                }
                
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(VaultCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(VaultColors.primary)
                }
                
                Section("Details") {
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    
                    DatePicker("Document Date", selection: $documentDate, displayedComponents: .date)
                        .tint(VaultColors.primary)
                }
                
                Section("Provider Information") {
                    TextField("Doctor/Provider Name", text: $doctorName)
                    TextField("Hospital/Clinic", text: $location)
                }
                
                Section("Reminders") {
                    Toggle("Set Reminder", isOn: $hasReminder)
                        .tint(VaultColors.primary)
                    if hasReminder {
                        DatePicker("Reminder", selection: $reminderDate, displayedComponents: [.date, .hourAndMinute])
                            .tint(VaultColors.primary)
                    }
                    
                    Toggle("Set Appointment", isOn: $hasAppointment)
                        .tint(VaultColors.primary)
                    if hasAppointment {
                        DatePicker("Appointment", selection: $appointmentDate, displayedComponents: [.date, .hourAndMinute])
                            .tint(VaultColors.primary)
                    }
                }
                
                Section {
                    TextField("Tags (comma separated)", text: $tags)
                } footer: {
                    Text("e.g., urgent, follow-up, annual")
                }
                
                if viewModel.uploadState.isUploading {
                    Section {
                        VStack(spacing: 12) {
                            ProgressView(value: viewModel.uploadState.progress)
                                .progressViewStyle(.linear)
                                .tint(VaultColors.primary)
                            
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
                    .foregroundColor(VaultColors.primary)
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

// MARK: - Vault Document Detail Sheet

private struct VaultDocumentDetailSheet: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    let onView: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var fileURL: URL?
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            List {
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
                
                if document.documentDate != nil || document.reminderDate != nil || document.appointmentDate != nil {
                    Section("Timeline") {
                        if let date = document.documentDate {
                            VaultLabeledRow(icon: "calendar", iconColor: VaultColors.primary, label: "Document Date", value: formatDate(date))
                        }
                        if let date = document.reminderDate {
                            VaultLabeledRow(icon: "bell.fill", iconColor: .orange, label: "Reminder", value: formatDateTime(date))
                        }
                        if let date = document.appointmentDate {
                            VaultLabeledRow(icon: "calendar.badge.clock", iconColor: VaultColors.purple, label: "Appointment", value: formatDateTime(date))
                        }
                    }
                }
                
                if let desc = document.description, !desc.isEmpty {
                    Section("Description") {
                        Text(desc)
                            .font(.body)
                    }
                }
                
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
                
                if let tags = document.tags, !tags.isEmpty {
                    Section("Tags") {
                        FlowLayout(spacing: 8) {
                            ForEach(tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(VaultColors.primary.opacity(0.2))
                                    .foregroundColor(VaultColors.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                Section("File Details") {
                    LabeledContent("Type", value: document.fileType.uppercased())
                    LabeledContent("Size", value: document.formattedFileSize)
                    LabeledContent("Uploaded", value: document.formattedDate)
                }
                
                Section {
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onView() }
                    } label: {
                        Label("View Document", systemImage: "eye.fill")
                            .foregroundColor(VaultColors.primary)
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
                VaultEditDocumentSheet(document: document, viewModel: viewModel)
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

// MARK: - Vault Labeled Row

private struct VaultLabeledRow: View {
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

// MARK: - Vault Edit Document Sheet

private struct VaultEditDocumentSheet: View {
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
                    .tint(VaultColors.primary)
                    
                    Toggle("Set Reminder", isOn: Binding(
                        get: { reminderDate != nil },
                        set: { reminderDate = $0 ? Date() : nil }
                    ))
                    .tint(VaultColors.primary)
                    
                    if reminderDate != nil {
                        DatePicker("Reminder", selection: Binding(
                            get: { reminderDate ?? Date() },
                            set: { reminderDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .tint(VaultColors.primary)
                    }
                    
                    Toggle("Set Appointment", isOn: Binding(
                        get: { appointmentDate != nil },
                        set: { appointmentDate = $0 ? Date() : nil }
                    ))
                    .tint(VaultColors.primary)
                    
                    if appointmentDate != nil {
                        DatePicker("Appointment", selection: Binding(
                            get: { appointmentDate ?? Date() },
                            set: { appointmentDate = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .tint(VaultColors.primary)
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
                    .foregroundColor(VaultColors.primary)
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

// MARK: - Vault Folder Detail Sheet

private struct VaultFolderDetailSheet: View {
    let folder: DocumentFolder
    @ObservedObject var viewModel: VaultViewModel
    let onViewDocument: (MedicalDocument) -> Void
    let onDocumentInfo: (MedicalDocument) -> Void
    let onDeleteDocument: (MedicalDocument) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var folderColor: Color {
        let hash = abs(folder.id.hashValue)
        let colors: [Color] = [VaultColors.primary, VaultColors.secondary, VaultColors.accent, VaultColors.purple]
        return colors[hash % colors.count]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    folderHeader
                    filesGrid
                }
                .padding(20)
            }
            .background(VaultColors.background(for: colorScheme))
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
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(VaultColors.card(for: colorScheme))
        )
    }
    
    private var filesGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)
        ]
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(folder.documents) { document in
                VaultFileGridItem(
                    document: document,
                    viewModel: viewModel,
                    colorScheme: colorScheme,
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

// MARK: - Vault File Grid Item

private struct VaultFileGridItem: View {
    let document: MedicalDocument
    @ObservedObject var viewModel: VaultViewModel
    let colorScheme: ColorScheme
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
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(VaultColors.card(for: colorScheme))
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
            Button { onTap() } label: { Label("Open", systemImage: "eye") }
            Button { onInfo() } label: { Label("Info", systemImage: "info.circle") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
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

// MARK: - Vault Document Picker

private struct VaultDocumentPickerView: UIViewControllerRepresentable {
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
