//
//  VaultManager.swift
//  swastricare-mobile-swift
//
//  Created by Nikhil Deepak on 06/01/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class VaultManager: ObservableObject {
    static let shared = VaultManager()
    
    @Published var documents: [MedicalDocument] = []
    @Published var filteredDocuments: [MedicalDocument] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var uploadProgress: Double = 0.0
    @Published var selectedCategory: String? = nil
    @Published var searchQuery: String = "" {
        didSet {
            applyFilters()
        }
    }
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Fetch Documents
    
    func fetchDocuments(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        do {
            documents = try await supabase.fetchUserDocuments()
            applyFilters()
        } catch {
            errorMessage = "Failed to load documents: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Upload Document
    
    func uploadDocument(fileData: Data, fileName: String, category: String, notes: String? = nil) async {
        isLoading = true
        errorMessage = nil
        uploadProgress = 0.0
        
        do {
            // Simulate progress (in real app, you'd track actual upload progress)
            uploadProgress = 0.3
            
            let document = try await supabase.uploadDocument(
                fileData: fileData,
                fileName: fileName,
                category: category,
                notes: notes
            )
            
            uploadProgress = 1.0
            
            // Add to local list
            documents.insert(document, at: 0)
            applyFilters()
            
            // Reset progress after a short delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            uploadProgress = 0.0
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            uploadProgress = 0.0
        }
        
        isLoading = false
    }
    
    // MARK: - Delete Document
    
    func deleteDocument(_ document: MedicalDocument) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.deleteDocument(document: document)
            
            // Remove from local list
            if let index = documents.firstIndex(where: { $0.id == document.id }) {
                documents.remove(at: index)
            }
            applyFilters()
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Download Document
    
    func downloadDocument(_ document: MedicalDocument) async -> Data? {
        do {
            let data = try await supabase.downloadDocument(storagePath: document.fileUrl)
            return data
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Search
    
    func searchDocuments(_ query: String) async {
        guard !query.isEmpty else {
            searchQuery = ""
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            documents = try await supabase.searchDocuments(query: query)
            applyFilters()
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Filtering
    
    func setCategory(_ category: String?) {
        selectedCategory = category
        applyFilters()
    }
    
    private func applyFilters() {
        var filtered = documents
        
        // Apply category filter
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Apply search filter
        if !searchQuery.isEmpty {
            filtered = filtered.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                ($0.notes?.localizedCaseInsensitiveContains(searchQuery) ?? false)
            }
        }
        
        filteredDocuments = filtered
    }
    
    // MARK: - Category Counts
    
    func documentCount(for category: String) -> Int {
        return documents.filter { $0.category == category }.count
    }
    
    func totalDocumentCount() -> Int {
        return documents.count
    }
    
    // MARK: - Helper Methods
    
    func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    func iconForFileType(_ fileType: String) -> String {
        switch fileType.uppercased() {
        case "PDF":
            return "doc.text.fill"
        case "JPG", "JPEG", "PNG", "HEIC":
            return "photo.fill"
        case "DICOM":
            return "film.fill"
        default:
            return "doc.fill"
        }
    }
    
    func colorForFileType(_ fileType: String) -> Color {
        switch fileType.uppercased() {
        case "PDF":
            return .red
        case "JPG", "JPEG", "PNG", "HEIC":
            return .blue
        case "DICOM":
            return .purple
        default:
            return .gray
        }
    }
}
