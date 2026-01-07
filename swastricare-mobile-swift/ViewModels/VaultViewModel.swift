//
//  VaultViewModel.swift
//  swastricare-mobile-swift
//
//  MVVM Architecture - ViewModel Layer
//

import Foundation
import Combine

@MainActor
final class VaultViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var documents: [MedicalDocument] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var uploadState = DocumentUploadState.idle
    @Published var searchQuery = ""
    @Published var selectedCategory: VaultCategory?
    @Published var showUploadSheet = false
    
    // MARK: - Upload Form State
    
    @Published var uploadFileName = ""
    @Published var uploadCategory: VaultCategory = .prescriptions
    @Published var uploadNotes = ""
    @Published var uploadFileData: Data?
    
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
    
    var canUpload: Bool {
        !uploadFileName.isEmpty && uploadFileData != nil
    }
    
    // MARK: - Dependencies
    
    private let vaultService: VaultServiceProtocol
    
    // MARK: - Init
    
    init(vaultService: VaultServiceProtocol = VaultService.shared) {
        self.vaultService = vaultService
    }
    
    // MARK: - Actions
    
    func loadDocuments() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            documents = try await vaultService.fetchDocuments()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func uploadDocument() async -> Bool {
        guard let fileData = uploadFileData, !uploadFileName.isEmpty else {
            errorMessage = "Please select a file"
            return false
        }
        
        uploadState = DocumentUploadState(isUploading: true, progress: 0.1)
        errorMessage = nil
        
        do {
            uploadState.progress = 0.3
            
            let document = try await vaultService.uploadDocument(
                fileData: fileData,
                fileName: uploadFileName,
                category: uploadCategory.rawValue,
                notes: uploadNotes.isEmpty ? nil : uploadNotes
            )
            
            uploadState.progress = 0.9
            
            // Add to beginning of list
            documents.insert(document, at: 0)
            
            uploadState.progress = 1.0
            
            // Reset form
            resetUploadForm()
            
            // Small delay before resetting progress
            try? await Task.sleep(nanoseconds: 300_000_000)
            uploadState = .idle
            
            return true
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            uploadState = DocumentUploadState(error: error.localizedDescription)
            return false
        }
    }
    
    func deleteDocument(_ document: MedicalDocument) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await vaultService.deleteDocument(document)
            documents.removeAll { $0.id == document.id }
            isLoading = false
            return true
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func downloadDocument(_ document: MedicalDocument) async -> Data? {
        do {
            return try await vaultService.downloadDocument(storagePath: document.fileUrl)
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    func setCategory(_ category: VaultCategory?) {
        selectedCategory = category
    }
    
    // MARK: - Helpers
    
    func resetUploadForm() {
        uploadFileName = ""
        uploadCategory = .prescriptions
        uploadNotes = ""
        uploadFileData = nil
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    func prepareUpload(fileName: String, fileData: Data) {
        uploadFileName = fileName
        uploadFileData = fileData
        
        // Try to auto-detect category from filename
        let lowercaseName = fileName.lowercased()
        if lowercaseName.contains("prescription") || lowercaseName.contains("rx") {
            uploadCategory = .prescriptions
        } else if lowercaseName.contains("lab") || lowercaseName.contains("blood") || lowercaseName.contains("test") {
            uploadCategory = .labReports
        } else if lowercaseName.contains("xray") || lowercaseName.contains("mri") || lowercaseName.contains("scan") {
            uploadCategory = .imaging
        } else if lowercaseName.contains("insurance") || lowercaseName.contains("claim") {
            uploadCategory = .insurance
        }
        
        showUploadSheet = true
    }
}

