//
//  VaultView.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import SwiftUI

struct VaultView: View {
    @StateObject private var vaultManager = VaultManager.shared
    
    @State private var showFilePicker = false
    @State private var showUploadSheet = false
    @State private var selectedDocument: MedicalDocument?
    @State private var searchText = ""
    
    // Upload state
    @State private var pendingFileData: Data?
    @State private var pendingFileName: String?
    @State private var selectedUploadCategory = "Lab Reports"
    @State private var uploadNotes = ""
    @State private var showError = false
    @State private var errorText = ""
    
    private let categories = [
        VaultCategory(name: "Lab Reports", icon: "testtube.2", color: .blue),
        VaultCategory(name: "Prescriptions", icon: "pills.fill", color: .green),
        VaultCategory(name: "Insurance", icon: "shield.fill", color: .orange),
        VaultCategory(name: "Imaging", icon: "waveform.path.ecg", color: .purple)
    ]
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HeroHeader(
                        title: "Medical Vault",
                        subtitle: "Secure Storage",
                        icon: "lock.shield.fill"
                    )
                    
                    // Search Bar
                    searchBar
                    
                    // Categories Grid
                    categoriesSection
                    
                    // Documents List
                    documentsSection
                    
                    // Bottom Padding for Dock and FAB
                    Color.clear.frame(height: 120)
                }
                .padding(.top)
            }
            .refreshable {
                await vaultManager.fetchDocuments(forceRefresh: true)
            }
            
            // Upload Progress Overlay
            if vaultManager.uploadProgress > 0 && vaultManager.uploadProgress < 1 {
                uploadProgressOverlay
            }
            
            // Floating Action Button
            floatingActionButton
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorText)
        }
        .sheet(isPresented: $showFilePicker) {
            FilePicker(isPresented: $showFilePicker) { data, fileName in
                handleFilePicked(data: data, fileName: fileName)
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            uploadSheet
        }
        .fullScreenCover(item: $selectedDocument) { document in
            DocumentViewer(document: document)
        }
        .task {
            await vaultManager.fetchDocuments()
        }
        .onChange(of: vaultManager.errorMessage) { _, newValue in
            if let error = newValue {
                errorText = error
                showError = true
                vaultManager.clearError()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search records...", text: $searchText)
                .foregroundColor(.primary)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    vaultManager.setSearchQuery(newValue)
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    vaultManager.setSearchQuery("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .glass(cornerRadius: 16)
        .padding(.horizontal)
    }
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Categories")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if vaultManager.selectedCategory != nil {
                    Button {
                        vaultManager.setCategory(nil)
                    } label: {
                        Text("Show All")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                ForEach(categories) { category in
                    VaultCategoryCard(
                        category: category,
                        count: vaultManager.documentCount(for: category.name),
                        isSelected: vaultManager.selectedCategory == category.name
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if vaultManager.selectedCategory == category.name {
                                vaultManager.setCategory(nil)
                            } else {
                                vaultManager.setCategory(category.name)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(vaultManager.selectedCategory ?? "All Documents")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            if vaultManager.isLoading && vaultManager.documents.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if vaultManager.filteredDocuments.isEmpty {
                EmptyStateView(
                    icon: "folder",
                    title: "No documents yet",
                    message: "Upload your first medical document to get started"
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(vaultManager.filteredDocuments) { document in
                        VaultDocumentRow(document: document)
                            .onTapGesture {
                                selectedDocument = document
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await vaultManager.deleteDocument(document)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var uploadProgressOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                ProgressView(value: vaultManager.uploadProgress)
                    .progressViewStyle(.linear)
                Text("Uploading...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .padding(40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
    }
    
    private var floatingActionButton: some View {
        Button {
            showFilePicker = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 100)
    }
    
    @ViewBuilder
    private var uploadSheet: some View {
        if let data = pendingFileData, let fileName = pendingFileName {
            UploadDocumentSheet(
                fileData: data,
                fileName: fileName,
                selectedCategory: $selectedUploadCategory,
                notes: $uploadNotes,
                onUpload: { category, notes in
                    Task {
                        let success = await vaultManager.uploadDocument(
                            fileData: data,
                            fileName: fileName,
                            category: category,
                            notes: notes.isEmpty ? nil : notes
                        )
                        
                        if success {
                            resetUploadState()
                            showUploadSheet = false
                        }
                    }
                },
                onCancel: {
                    resetUploadState()
                    showUploadSheet = false
                }
            )
        }
    }
    
    // MARK: - Methods
    
    private func handleFilePicked(data: Data, fileName: String) {
        // Validate file
        let validation = FileValidator.validate(data: data, fileName: fileName)
        
        if validation.isValid {
            pendingFileData = data
            pendingFileName = fileName
            selectedUploadCategory = "Lab Reports"
            uploadNotes = ""
            
            // Small delay to ensure file picker sheet is dismissed first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showUploadSheet = true
            }
        } else {
            errorText = validation.error ?? "Invalid file"
            showError = true
        }
    }
    
    private func resetUploadState() {
        pendingFileData = nil
        pendingFileName = nil
        uploadNotes = ""
        selectedUploadCategory = "Lab Reports"
    }
}

// MARK: - Supporting Views

struct VaultCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
}

struct VaultCategoryCard: View {
    let category: VaultCategory
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [category.color.opacity(0.2), category.color.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: category.icon)
                            .foregroundColor(category.color)
                            .font(.title3)
                    )
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(category.color)
                        .cornerRadius(8)
                }
            }
            
            Text(category.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .glass(cornerRadius: 20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? category.color : Color.clear, lineWidth: 2)
        )
    }
}

struct VaultDocumentRow: View {
    let document: MedicalDocument
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: iconForType)
                .font(.title2)
                .foregroundColor(colorForType)
                .padding(10)
                .background(colorForType.opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(formattedDate)
                    Text("•")
                    Text(document.fileType)
                    Text("•")
                    Text(formattedSize)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .glass(cornerRadius: 16)
    }
    
    private var iconForType: String {
        switch document.fileType.uppercased() {
        case "PDF": return "doc.text.fill"
        case "JPG", "JPEG", "PNG", "HEIC": return "photo.fill"
        case "DOC", "DOCX": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }
    
    private var colorForType: Color {
        switch document.fileType.uppercased() {
        case "PDF": return .red
        case "JPG", "JPEG", "PNG", "HEIC": return .blue
        case "DOC", "DOCX": return .indigo
        default: return .gray
        }
    }
    
    private var formattedDate: String {
        guard let date = document.uploadedAt else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: document.fileSize)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
}

struct UploadDocumentSheet: View {
    let fileData: Data
    let fileName: String
    @Binding var selectedCategory: String
    @Binding var notes: String
    let onUpload: (String, String) -> Void
    let onCancel: () -> Void
    
    @State private var localCategory: String = "Lab Reports"
    @State private var localNotes: String = ""
    
    private let categoryOptions = ["Lab Reports", "Prescriptions", "Insurance", "Imaging"]
    
    init(fileData: Data, fileName: String, selectedCategory: Binding<String>, notes: Binding<String>, onUpload: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.fileData = fileData
        self.fileName = fileName
        self._selectedCategory = selectedCategory
        self._notes = notes
        self.onUpload = onUpload
        self.onCancel = onCancel
        self._localCategory = State(initialValue: selectedCategory.wrappedValue)
        self._localNotes = State(initialValue: notes.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // File Preview Section
                Section("Preview") {
                    VStack(spacing: 12) {
                        filePreview
                        
                        VStack(spacing: 4) {
                            Text(fileName)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            Text("\(fileSize) • \(fileType)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                
                Section("Category") {
                    Picker("Select Category", selection: $localCategory) {
                        ForEach(categoryOptions, id: \.self) { category in
                            HStack {
                                Image(systemName: iconForCategory(category))
                                    .foregroundColor(colorForCategory(category))
                                Text(category)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $localNotes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Upload") {
                        onUpload(localCategory, localNotes)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    @ViewBuilder
    private var filePreview: some View {
        if let image = UIImage(data: fileData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .cornerRadius(12)
        } else {
            VStack(spacing: 8) {
                Image(systemName: iconForFileType(fileType))
                    .font(.system(size: 50))
                    .foregroundColor(colorForFileType(fileType))
                
                Text(fileType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
        }
    }
    
    private var fileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileData.count))
    }
    
    private var fileType: String {
        FileValidator.getFileType(from: fileName)
    }
    
    private func iconForFileType(_ type: String) -> String {
        switch type.uppercased() {
        case "PDF": return "doc.text.fill"
        case "JPG", "JPEG", "PNG", "HEIC": return "photo.fill"
        case "DOC", "DOCX": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }
    
    private func colorForFileType(_ type: String) -> Color {
        switch type.uppercased() {
        case "PDF": return .red
        case "JPG", "JPEG", "PNG", "HEIC": return .blue
        case "DOC", "DOCX": return .indigo
        default: return .gray
        }
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Lab Reports": return "testtube.2"
        case "Prescriptions": return "pills.fill"
        case "Insurance": return "shield.fill"
        case "Imaging": return "waveform.path.ecg"
        default: return "doc.fill"
        }
    }
    
    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Lab Reports": return .blue
        case "Prescriptions": return .green
        case "Insurance": return .orange
        case "Imaging": return .purple
        default: return .gray
        }
    }
}
