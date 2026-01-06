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
    
    // MARK: - Published Properties
    @Published var documents: [MedicalDocument] = []
    @Published var filteredDocuments: [MedicalDocument] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var uploadProgress: Double = 0.0
    @Published var selectedCategory: String?
    @Published var searchQuery: String = ""
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Fetch Documents
    
    func fetchDocuments(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            documents = try await supabase.fetchUserDocuments()
            updateFilteredDocuments()
        } catch {
            errorMessage = error.localizedDescription
            print("VaultManager: Fetch error - \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Upload Document
    
    func uploadDocument(fileData: Data, fileName: String, category: String, notes: String?) async -> Bool {
        guard !fileData.isEmpty else {
            errorMessage = "File is empty"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        uploadProgress = 0.1
        
        do {
            uploadProgress = 0.3
            
            let document = try await supabase.uploadDocument(
                fileData: fileData,
                fileName: fileName,
                category: category,
                notes: notes
            )
            
            uploadProgress = 0.9
            
            // Add to beginning of list
            documents.insert(document, at: 0)
            updateFilteredDocuments()
            
            uploadProgress = 1.0
            
            // Small delay before resetting progress
            try? await Task.sleep(nanoseconds: 300_000_000)
            uploadProgress = 0.0
            isLoading = false
            
            return true
        } catch {
            errorMessage = "Upload failed: \(error.localizedDescription)"
            print("VaultManager: Upload error - \(error)")
            uploadProgress = 0.0
            isLoading = false
            return false
        }
    }
    
    // MARK: - Delete Document
    
    func deleteDocument(_ document: MedicalDocument) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabase.deleteDocument(document: document)
            
            // Remove from local array
            documents.removeAll { $0.id == document.id }
            updateFilteredDocuments()
            
            isLoading = false
            return true
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            print("VaultManager: Delete error - \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Download Document
    
    func downloadDocument(_ document: MedicalDocument) async -> Data? {
        do {
            return try await supabase.downloadDocument(storagePath: document.fileUrl)
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
            print("VaultManager: Download error - \(error)")
            return nil
        }
    }
    
    // MARK: - Filtering
    
    func setCategory(_ category: String?) {
        selectedCategory = category
        updateFilteredDocuments()
    }
    
    func setSearchQuery(_ query: String) {
        searchQuery = query
        updateFilteredDocuments()
    }
    
    private func updateFilteredDocuments() {
        var result = documents
        
        // Filter by category
        if let category = selectedCategory, !category.isEmpty {
            result = result.filter { $0.category == category }
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
        
        filteredDocuments = result
    }
    
    // MARK: - Helper Methods
    
    func documentCount(for category: String) -> Int {
        documents.filter { $0.category == category }.count
    }
    
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
    
    func colorForFileType(_ fileType: String) -> Color {
        switch fileType.uppercased() {
        case "PDF":
            return .red
        case "JPG", "JPEG", "PNG", "HEIC":
            return .blue
        case "DOC", "DOCX":
            return .indigo
        case "TXT", "RTF":
            return .gray
        case "CSV":
            return .green
        default:
            return .gray
        }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
