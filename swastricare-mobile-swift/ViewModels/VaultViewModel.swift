//
//  VaultViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//  Enhanced with multiple file support
//

import Foundation
import Combine
import SwiftUI

// MARK: - Pending Upload Model

struct PendingUpload: Equatable {
    let fileName: String
    let fileData: Data
    var category: VaultCategory
    var metadata: DocumentMetadata
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileData.count))
    }
    
    var icon: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.text.fill"
        case "jpg", "jpeg", "png", "heic": return "photo.fill"
        case "doc", "docx": return "doc.richtext.fill"
        default: return "doc.fill"
        }
    }
}

// MARK: - Sort Order

enum VaultSortOrder {
    case dateDescending
    case dateAscending
    case timelineDescending // By document_date
    case timelineAscending
    case nameAscending
    case nameDescending
    case sizeDescending
}

// MARK: - View Mode

enum VaultViewMode {
    case list      // Individual files
    case folders   // Grouped by visit/metadata
    case timeline  // Chronological timeline view
}

// MARK: - Timeline Models

struct TimelineItem: Identifiable, Equatable {
    let id: UUID
    let date: Date
    let type: TimelineItemType
    let doctorName: String?
    let location: String?
    let folderName: String?
}

enum TimelineItemType: Equatable {
    case document(MedicalDocument)
    case consultation(doctorName: String?, location: String?, date: Date)
    
    static func == (lhs: TimelineItemType, rhs: TimelineItemType) -> Bool {
        switch (lhs, rhs) {
        case (.document(let doc1), .document(let doc2)):
            return doc1.id == doc2.id
        case (.consultation(let doc1, let loc1, let date1), .consultation(let doc2, let loc2, let date2)):
            return doc1 == doc2 && loc1 == loc2 && date1 == date2
        default:
            return false
        }
    }
}

// MARK: - Document Folder (Group)

struct DocumentFolder: Identifiable, Equatable {
    let id: String  // Unique key based on metadata
    let documents: [MedicalDocument]
    
    // Shared metadata from documents
    var folderName: String? { 
        documents.first?.folderName
    }
    var documentDate: Date? { documents.first?.documentDate }
    var doctorName: String? { documents.first?.doctorName }
    var location: String? { documents.first?.location }
    var description: String? { documents.first?.description }
    var tags: [String]? { documents.first?.tags }
    var category: String { documents.first?.category ?? "Unknown" }
    
    var fileCount: Int { documents.count }
    
    var totalSize: Int64 {
        documents.reduce(0) { $0 + $1.fileSize }
    }
    
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var folderTitle: String {
        // Use folder name first if available
        if let name = folderName, !name.isEmpty {
            return name
        }
        if let doc = doctorName, !doc.isEmpty {
            return doc
        }
        if let loc = location, !loc.isEmpty {
            return loc
        }
        if let date = documentDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return category
    }
    
    var subtitle: String {
        var parts: [String] = []
        if let date = documentDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append(formatter.string(from: date))
        }
        if let loc = location, !loc.isEmpty, doctorName != nil {
            parts.append(loc)
        }
        parts.append("\(fileCount) file\(fileCount == 1 ? "" : "s")")
        return parts.joined(separator: " • ")
    }
    
    var shortSubtitle: String {
        if let date = documentDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
        return "\(fileCount) items"
    }
    
    static func == (lhs: DocumentFolder, rhs: DocumentFolder) -> Bool {
        lhs.id == rhs.id && lhs.documents.count == rhs.documents.count
    }
}

// MARK: - ViewModel

@MainActor
final class VaultViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var documents: [MedicalDocument] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var uploadState = DocumentUploadState.idle
    @Published private(set) var currentUploadIndex = 0
    @Published private(set) var totalUploadFiles = 0
    
    @Published var searchQuery = ""
    @Published var selectedCategory: VaultCategory?
    @Published var showUploadSheet = false
    @Published var sortOrder: VaultSortOrder = .dateDescending
    @Published var viewMode: VaultViewMode = .folders  // Default to folders
    
    // MARK: - Upload State
    
    @Published var pendingUploads: [PendingUpload] = []
    @Published var uploadCategory: VaultCategory = .prescriptions
    
    // MARK: - Computed Properties
    
    var filteredDocuments: [MedicalDocument] {
        var result = documents
        
        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category.rawValue }
        }
        
        // Filter by search query
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                ($0.notes?.lowercased().contains(query) ?? false) ||
                $0.category.lowercased().contains(query)
            }
        }
        
        // Sort
        result = sortDocuments(result)
        
        return result
    }
    
    var documentsByCategory: [VaultCategory: Int] {
        var counts: [VaultCategory: Int] = [:]
        for category in VaultCategory.allCases {
            counts[category] = documents.filter { $0.category == category.rawValue }.count
        }
        return counts
    }
    
    var totalDocuments: Int { documents.count }
    
    var totalStorageFormatted: String {
        let totalBytes = documents.reduce(0) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalBytes)
    }
    
    var canUpload: Bool {
        !pendingUploads.isEmpty
    }
    
    // Group documents into folders based on shared metadata
    var groupedDocuments: [DocumentFolder] {
        // Group by folderName first, then by documentDate + doctorName + location
        let grouped = Dictionary(grouping: filteredDocuments) { document -> String in
            var key = ""
            
            // Use folderName as primary grouping key if available
            if let name = document.folderName, !name.isEmpty {
                key = "folder_\(name)"
            } else {
                // Use document date as primary grouping key
                if let date = document.documentDate {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd"
                    key += formatter.string(from: date)
                }
                
                // Add doctor name
                if let doctor = document.doctorName, !doctor.isEmpty {
                    key += "_\(doctor)"
                }
                
                // Add location
                if let location = document.location, !location.isEmpty {
                    key += "_\(location)"
                }
                
                // If no metadata, use individual document ID to keep it separate
                if key.isEmpty {
                    key = document.id?.uuidString ?? UUID().uuidString
                }
            }
            
            return key
        }
        
        // Convert to folders
        var folders = grouped.map { (key, docs) in
            DocumentFolder(id: key, documents: docs)
        }
        
        // Sort folders by document date (newest first)
        folders.sort { folder1, folder2 in
            let date1 = folder1.documentDate ?? folder1.documents.first?.createdAt ?? Date.distantPast
            let date2 = folder2.documentDate ?? folder2.documents.first?.createdAt ?? Date.distantPast
            return date1 > date2
        }
        
        return folders
    }
    
    // Timeline items grouped by date
    var timelineItems: [TimelineItem] {
        var items: [TimelineItem] = []
        
        // Create timeline items from documents
        for document in filteredDocuments {
            // For date grouping, use documentDate, appointmentDate, or reminderDate
            let dateForGrouping = document.documentDate ?? 
                                 document.appointmentDate ?? 
                                 document.reminderDate ?? 
                                 document.uploadedAt ?? 
                                 document.createdAt ?? 
                                 Date()
            
            // For time display, combine the date from documentDate with time from uploadedAt/createdAt
            // This ensures we show the correct time (not midnight from date-only fields)
            let displayDate: Date
            if let docDate = document.documentDate ?? document.appointmentDate ?? document.reminderDate,
               let timeSource = document.uploadedAt ?? document.createdAt {
                // Combine date from documentDate with time from uploadedAt/createdAt
                let calendar = Calendar.current
                let dateComponents = calendar.dateComponents([.year, .month, .day], from: docDate)
                let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeSource)
                var combinedComponents = DateComponents()
                combinedComponents.year = dateComponents.year
                combinedComponents.month = dateComponents.month
                combinedComponents.day = dateComponents.day
                combinedComponents.hour = timeComponents.hour
                combinedComponents.minute = timeComponents.minute
                combinedComponents.second = timeComponents.second
                displayDate = calendar.date(from: combinedComponents) ?? timeSource
            } else {
                // Use uploadedAt or createdAt directly (they have proper timestamps)
                displayDate = document.uploadedAt ?? document.createdAt ?? dateForGrouping
            }
            
            items.append(TimelineItem(
                id: document.id ?? UUID(),
                date: displayDate,
                type: .document(document),
                doctorName: document.doctorName,
                location: document.location,
                folderName: document.folderName
            ))
        }
        
        // Sort by date (newest first)
        return items.sorted { $0.date > $1.date }
    }
    
    func setViewMode(_ mode: VaultViewMode) {
        viewMode = mode
    }
    
    // MARK: - Dependencies
    
    let vaultService: VaultServiceProtocol
    
    // MARK: - Init
    
    init(vaultService: VaultServiceProtocol = VaultService.shared) {
        self.vaultService = vaultService
    }
    
    // MARK: - Sort Helper
    
    private func sortDocuments(_ docs: [MedicalDocument]) -> [MedicalDocument] {
        switch sortOrder {
        case .dateDescending:
            return docs.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .dateAscending:
            return docs.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .timelineDescending:
            return docs.sorted { 
                ($0.documentDate ?? $0.createdAt ?? Date.distantPast) > 
                ($1.documentDate ?? $1.createdAt ?? Date.distantPast) 
            }
        case .timelineAscending:
            return docs.sorted { 
                ($0.documentDate ?? $0.createdAt ?? Date.distantPast) < 
                ($1.documentDate ?? $1.createdAt ?? Date.distantPast) 
            }
        case .nameAscending:
            return docs.sorted { $0.title.lowercased() < $1.title.lowercased() }
        case .nameDescending:
            return docs.sorted { $0.title.lowercased() > $1.title.lowercased() }
        case .sizeDescending:
            return docs.sorted { $0.fileSize > $1.fileSize }
        }
    }
    
    // MARK: - Actions
    
    func loadDocuments() async {
        // Clear any previous errors
        errorMessage = nil
        
        // Set loading state only if not already loading (to prevent UI flicker during refresh)
        let wasLoading = isLoading
        if !wasLoading {
            isLoading = true
        }
        
        do {
            // Fetch documents
            let fetched = try await vaultService.fetchDocuments()
            documents = fetched
            isLoading = false
            print("✅ Loaded \(fetched.count) documents")
        } catch {
            // Handle cancellation gracefully (don't show error for cancelled refreshes)
            if error is CancellationError {
                isLoading = false
                print("ℹ️ Document fetch was cancelled")
                return
            }
            
            // Handle other errors
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            isLoading = false
            print("❌ Failed to load documents: \(errorMsg)")
        }
    }
    
    func prepareMultipleUploads(files: [(String, Data)]) {
        pendingUploads = files.map { fileName, data in
            // Auto-detect category
            let category = detectCategory(from: fileName)
            return PendingUpload(
                fileName: fileName,
                fileData: data,
                category: category,
                metadata: DocumentMetadata(name: fileName)
            )
        }
        
        if !pendingUploads.isEmpty {
            showUploadSheet = true
        }
    }
    
    func updatePendingUploadMetadata(_ upload: PendingUpload, metadata: DocumentMetadata) {
        if let index = pendingUploads.firstIndex(where: { $0.fileName == upload.fileName }) {
            pendingUploads[index].metadata = metadata
        }
    }
    
    func removePendingUpload(_ upload: PendingUpload) {
        pendingUploads.removeAll { $0.fileName == upload.fileName }
        
        if pendingUploads.isEmpty {
            showUploadSheet = false
        }
    }
    
    func applySharedMetadata(_ metadata: DocumentMetadata, category: VaultCategory) {
        // Apply shared metadata to all pending uploads
        for index in pendingUploads.indices {
            // Keep the original file name but apply shared metadata
            var updatedMetadata = metadata
            updatedMetadata.name = pendingUploads[index].fileName
            
            pendingUploads[index].metadata = updatedMetadata
            pendingUploads[index].category = category
        }
    }
    
    func uploadAllDocuments() async {
        guard !pendingUploads.isEmpty else { return }
        
        // Store a copy of pending uploads before starting (in case it gets modified)
        let uploadsToProcess = pendingUploads
        let totalFiles = uploadsToProcess.count
        
        uploadState = DocumentUploadState(isUploading: true, progress: 0.0)
        errorMessage = nil
        currentUploadIndex = 0
        totalUploadFiles = totalFiles
        
        var successCount = 0
        
        for (index, upload) in uploadsToProcess.enumerated() {
            // Update current index and progress BEFORE upload
            currentUploadIndex = index
            uploadState.progress = Double(index) / Double(totalFiles)
            
            do {
                print("📤 Uploading file \(index + 1)/\(totalFiles): \(upload.fileName)")
                print("   Size: \(ByteCountFormatter.string(fromByteCount: Int64(upload.fileData.count), countStyle: .file))")
                print("   Category: \(upload.category.rawValue)")
                
                let document = try await vaultService.uploadDocument(
                    fileData: upload.fileData,
                    fileName: upload.fileName,
                    category: upload.category.rawValue,
                    metadata: upload.metadata
                )
                
                print("✅ Successfully uploaded: \(upload.fileName)")
                
                // Add to beginning of list
                documents.insert(document, at: 0)
                successCount += 1
                
                // Update progress AFTER successful upload
                uploadState.progress = Double(index + 1) / Double(totalFiles)
            } catch {
                let errorDesc = error.localizedDescription
                print("❌ Failed to upload \(upload.fileName): \(errorDesc)")
                print("   Error type: \(type(of: error))")
                
                // Continue with other files, but still update progress
                uploadState.progress = Double(index + 1) / Double(totalFiles)
                
                // Store error for this file (append if multiple errors)
                let fileError = "\(upload.fileName): \(errorDesc)"
                if errorMessage == nil {
                    errorMessage = fileError
                } else {
                    errorMessage = "\(errorMessage ?? "")\n\(fileError)"
                }
            }
        }
        
        // Final cleanup
        uploadState.progress = 1.0
        
        // Refresh documents list to ensure consistency
        if successCount > 0 {
            do {
                let refreshed = try await vaultService.fetchDocuments()
                documents = refreshed
            } catch {
                print("⚠️ Failed to refresh documents after upload: \(error)")
                // Don't fail the entire upload if refresh fails
            }
        }
        
        // Clean up after a short delay to show completion
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        
        pendingUploads.removeAll()
        uploadState = .idle
        totalUploadFiles = 0
        showUploadSheet = false
        
        if successCount < totalFiles {
            let message = "Uploaded \(successCount) of \(totalFiles) files. Some files failed."
            if errorMessage == nil {
                errorMessage = message
            } else {
                errorMessage = "\(message) \(errorMessage ?? "")"
            }
        }
    }
    
    func cancelUpload() {
        pendingUploads.removeAll()
        uploadState = .idle
        totalUploadFiles = 0
        showUploadSheet = false
    }
    
    @discardableResult
    func deleteDocument(_ document: MedicalDocument) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await vaultService.deleteDocument(document)
            withAnimation {
                documents.removeAll { $0.id == document.id }
            }
            isLoading = false
            return true
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func downloadDocument(_ document: MedicalDocument) async throws -> Data {
        do {
            return try await vaultService.downloadDocument(storagePath: document.fileUrl)
        } catch {
            // Only set error message if it's not a cancellation
            if !(error is CancellationError) {
                errorMessage = "Download failed: \(error.localizedDescription)"
            }
            throw error
        }
    }
    
    func getDocumentURL(_ document: MedicalDocument) async -> URL? {
        do {
            // Get signed URL valid for 1 hour
            return try await vaultService.getSignedURL(storagePath: document.fileUrl, expiresIn: 3600)
        } catch {
            // Only set error message if it's not a cancellation
            if !(error is CancellationError) {
                errorMessage = "Failed to get document URL: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    func updateDocument(_ document: MedicalDocument, metadata: DocumentMetadata) async throws -> MedicalDocument {
        return try await vaultService.updateDocument(document, metadata: metadata)
    }
    
    func setCategory(_ category: VaultCategory?) {
        selectedCategory = category
    }
    
    func setSortOrder(_ order: VaultSortOrder) {
        sortOrder = order
    }
    
    // MARK: - Helpers
    
    private func detectCategory(from fileName: String) -> VaultCategory {
        let lowercaseName = fileName.lowercased()
        
        if lowercaseName.contains("prescription") || lowercaseName.contains("rx") || lowercaseName.contains("medicine") {
            return .prescriptions
        } else if lowercaseName.contains("lab") || lowercaseName.contains("blood") || lowercaseName.contains("test") || lowercaseName.contains("report") {
            return .labReports
        } else if lowercaseName.contains("xray") || lowercaseName.contains("mri") || lowercaseName.contains("scan") || lowercaseName.contains("ct") || lowercaseName.contains("ultrasound") {
            return .imaging
        } else if lowercaseName.contains("insurance") || lowercaseName.contains("claim") || lowercaseName.contains("policy") {
            return .insurance
        }
        
        return .labReports // Default
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // Legacy support for single file upload
    func prepareUpload(fileName: String, fileData: Data) {
        prepareMultipleUploads(files: [(fileName, fileData)])
    }
    
    func resetUploadForm() {
        pendingUploads.removeAll()
        uploadCategory = .prescriptions
    }
}

