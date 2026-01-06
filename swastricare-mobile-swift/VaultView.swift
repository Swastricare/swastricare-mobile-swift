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
    @State private var showCategoryPicker = false
    @State private var showUploadSheet = false
    @State private var selectedDocument: MedicalDocument?
    @State private var showDocumentViewer = false
    @State private var searchText = ""
    
    // Upload state
    @State private var pendingFileData: Data?
    @State private var pendingFileName: String?
    @State private var selectedUploadCategory = "Lab Reports"
    @State private var uploadNotes = ""
    @State private var validationError: String?
    @State private var showValidationAlert = false
    
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
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search records...", text: $searchText)
                            .foregroundColor(.primary)
                            .onChange(of: searchText) { newValue in
                                vaultManager.searchQuery = newValue
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                vaultManager.searchQuery = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .glass(cornerRadius: 16)
                    .padding(.horizontal)
                    
                    // Categories Grid
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Categories")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if vaultManager.selectedCategory != nil {
                                Button(action: {
                                    vaultManager.setCategory(nil)
                                }) {
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
                                    if vaultManager.selectedCategory == category.name {
                                        vaultManager.setCategory(nil)
                                    } else {
                                        vaultManager.setCategory(category.name)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Documents List
                    VStack(alignment: .leading, spacing: 15) {
                        Text(vaultManager.selectedCategory != nil ? vaultManager.selectedCategory! : "All Documents")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        if vaultManager.isLoading {
                            ProgressView()
                                .padding()
                        } else if vaultManager.filteredDocuments.isEmpty {
                            EmptyStateView(
                                icon: "folder",
                                title: "No documents yet",
                                message: "Upload your first medical document to get started"
                            )
                        } else {
                            VStack(spacing: 12) {
                                ForEach(vaultManager.filteredDocuments) { document in
                                    VaultDocumentRow(
                                        document: document,
                                        vaultManager: vaultManager
                                    )
                                    .onTapGesture {
                                        selectedDocument = document
                                        showDocumentViewer = true
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
                VStack {
                    ProgressView("Uploading...", value: vaultManager.uploadProgress, total: 1.0)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 10)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
            }
            
            // Floating Action Button
            Button(action: {
                showFilePicker = true
            }) {
                Image(systemName: "plus")
                    .font(.title2)
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
            .padding(.bottom, 100) // Above the dock
        }
        .alert("Error", isPresented: .constant(vaultManager.errorMessage != nil)) {
            Button("OK") {
                vaultManager.errorMessage = nil
            }
        } message: {
            if let error = vaultManager.errorMessage {
                Text(error)
            }
        }
        .alert("Invalid File", isPresented: $showValidationAlert) {
            Button("OK") {
                validationError = nil
            }
        } message: {
            if let error = validationError {
                Text(error)
            }
        }
        .sheet(isPresented: $showFilePicker) {
            FilePicker(isPresented: $showFilePicker) { data, fileName in
                // Validate file first
                let validation = FileValidator.validate(data: data, fileName: fileName)
                
                if validation.isValid {
                    // File is valid, proceed to tagging
                    pendingFileData = data
                    pendingFileName = fileName
                    showUploadSheet = true
                } else {
                    // Show validation error
                    validationError = validation.error
                    showValidationAlert = true
                }
            }
        }
        .sheet(isPresented: $showUploadSheet) {
            if let data = pendingFileData, let fileName = pendingFileName {
                UploadDocumentSheet(
                    fileData: data,
                    fileName: fileName,
                    selectedCategory: $selectedUploadCategory,
                    notes: $uploadNotes,
                    onUpload: {
                        Task {
                            await vaultManager.uploadDocument(
                                fileData: data,
                                fileName: fileName,
                                category: selectedUploadCategory,
                                notes: uploadNotes.isEmpty ? nil : uploadNotes
                            )
                            // Reset
                            uploadNotes = ""
                            pendingFileData = nil
                            pendingFileName = nil
                        }
                    },
                    onCancel: {
                        showUploadSheet = false
                        uploadNotes = ""
                        pendingFileData = nil
                        pendingFileName = nil
                    }
                )
            }
        }
        .fullScreenCover(item: $selectedDocument) { document in
            DocumentViewer(document: document)
        }
        .task {
            await vaultManager.fetchDocuments()
        }
    }
}

// MARK: - Vault Helpers

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
                        LinearGradient(colors: [category.color.opacity(0.2), category.color.opacity(0.1)], startPoint: .top, endPoint: .bottom)
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
                        .font(.caption)
                        .fontWeight(.bold)
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
    @ObservedObject var vaultManager: VaultManager
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: vaultManager.iconForFileType(document.fileType))
                .font(.title2)
                .foregroundColor(vaultManager.colorForFileType(document.fileType))
                .padding(10)
                .background(vaultManager.colorForFileType(document.fileType).opacity(0.1))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(vaultManager.formatDate(document.uploadedAt))
                    Text("•")
                    Text(document.fileType)
                    Text("•")
                    Text(vaultManager.formatFileSize(document.fileSize))
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
    let onUpload: () -> Void
    let onCancel: () -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    private let categories = ["Lab Reports", "Prescriptions", "Insurance", "Imaging"]
    
    private var fileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileData.count))
    }
    
    private var fileType: String {
        FileValidator.getFileType(from: fileName)
    }
    
    private var previewImage: UIImage? {
        // Try to create image from data
        UIImage(data: fileData)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // File Preview Section
                Section("Preview") {
                    VStack(spacing: 12) {
                        // Icon or Image Preview
                        if let image = previewImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(12)
                        } else {
                            // Show icon for non-image files
                            VStack(spacing: 8) {
                                Image(systemName: iconForFileType(fileType))
                                    .font(.system(size: 60))
                                    .foregroundColor(colorForFileType(fileType))
                                
                                Text(fileType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 120)
                        }
                        
                        // File Info
                        VStack(spacing: 4) {
                            Text(fileName)
                                .font(.subheadline)
                                .fontWeight(.medium)
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
                    Picker("Select Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
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
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Upload") {
                        onUpload()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // Helper functions
    private func iconForFileType(_ fileType: String) -> String {
        switch fileType.uppercased() {
        case "PDF":
            return "doc.text.fill"
        case "JPG", "JPEG", "PNG", "HEIC":
            return "photo.fill"
        case "DOC", "DOCX":
            return "doc.richtext.fill"
        case "TXT", "RTF":
            return "doc.plaintext.fill"
        case "CSV":
            return "tablecells.fill"
        default:
            return "doc.fill"
        }
    }
    
    private func colorForFileType(_ fileType: String) -> Color {
        switch fileType.uppercased() {
        case "PDF":
            return .red
        case "JPG", "JPEG", "PNG", "HEIC":
            return .blue
        case "DOC", "DOCX":
            return .blue
        case "TXT", "RTF":
            return .gray
        case "CSV":
            return .green
        default:
            return .gray
        }
    }
    
    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "Lab Reports":
            return "testtube.2"
        case "Prescriptions":
            return "pills.fill"
        case "Insurance":
            return "shield.fill"
        case "Imaging":
            return "waveform.path.ecg"
        default:
            return "doc.fill"
        }
    }
    
    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "Lab Reports":
            return .blue
        case "Prescriptions":
            return .green
        case "Insurance":
            return .orange
        case "Imaging":
            return .purple
        default:
            return .gray
        }
    }
}

